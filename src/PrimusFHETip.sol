// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPrimusZKTLS, Attestation} from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";
import {
    TipToken,
    EncryptedTipRecipientInfo,
    TipRecipient,
    EncryptedTipRecord,
    IdSource,
    ERC20_TYPE,
    NATIVE_TYPE
} from "./types/Common.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./utils/StringUtils.sol";
import "./utils/JsonParser.sol";
import "./utils/Currency.sol";

import "@sunscreen/contracts/Spf.sol";
import "@sunscreen/contracts/TfheThresholdDecryption.sol";

/**
 * Calls to the off-chain Secure Processing Framework (SPF) library for Primus FHE.
 *
 * All functions here have a corresponding function in the
 * `fhe-programs/src/primus-fhe.c` library. Please refer to that file for the
 * implementation details.
 */
library PrimusSpf {
    /**
     * To update this value, compile the SPF library and then acquire the hash
     * by uploading the resulting program to the SPF server. Please see the README
     * for instructions on how to generate this identifier.
     */
    Spf.SpfLibrary public constant PRIMUS_TIP_SPF_LIBRARY =
        Spf.SpfLibrary.wrap(0xc57120724dfd69eb50b284688d35fd748a7c6efa956e379092b8eb3ac9f921ea);

    // These program names should match the function names in the `primus-fhe.c` file.
    Spf.SpfProgram public constant PRIMUS_UPDATE_TIP_PROGRAM = Spf.SpfProgram.wrap("updateTip");
    Spf.SpfProgram public constant PRIMUS_ADD_TO_BALANCE_PROGRAM = Spf.SpfProgram.wrap("addToBalance");
    Spf.SpfProgram public constant PRIMUS_WITHDRAW_PROGRAM = Spf.SpfProgram.wrap("withdraw");

    /**
     * Update the tip amount and spent amount for the user, checking that the
     * user has enough balance to tip.
     *
     * @param amount The amount to tip (encrypted).
     * @param balance The current balance of the user (plaintext).
     * @param spent The current spent amount of the user (encrypted).
     * @return updatedAmount The updated amount after the tip (encrypted).
     * @return updatedSpent The updated spent amount after the tip (encrypted).
     */
    function updateTip(Spf.SpfParameter memory amount, uint256 balance, Spf.SpfParameter memory spent)
        internal
        returns (Spf.SpfParameter memory, Spf.SpfParameter memory)
    {
        // Pack the parameters for the SPF program.
        Spf.SpfParameter[] memory parameters = new Spf.SpfParameter[](6);
        parameters[0] = Spf.createPlaintextParameter(64, 0); // zero
        parameters[1] = amount;
        parameters[2] = Spf.createPlaintextParameter(64, balance); // balance
        parameters[3] = spent;
        parameters[4] = Spf.createOutputCiphertextParameter(64); // updatedAmount
        parameters[5] = Spf.createOutputCiphertextParameter(64); // updatedSpent

        // Notify the SPF server to run the program with the given parameters.
        Spf.SpfRunHandle runHandle = Spf.requestSpf(PRIMUS_TIP_SPF_LIBRARY, PRIMUS_UPDATE_TIP_PROGRAM, parameters);

        // Derive the updated amount and spent handles
        Spf.SpfParameter memory updatedAmount = Spf.getOutputHandle(runHandle, 0);
        Spf.SpfParameter memory updatedSpent = Spf.getOutputHandle(runHandle, 1);

        return (updatedAmount, updatedSpent);
    }

    /**
     * Add the given amount to the user's balance.
     *
     * @param amount The amount to add (encrypted).
     * @param balance The current balance of the user (encrypted).
     * @return updatedBalance The updated balance after adding the amount (encrypted).
     */
    function addToBalance(Spf.SpfParameter memory amount, Spf.SpfParameter memory balance)
        internal
        returns (Spf.SpfParameter memory)
    {
        Spf.SpfParameter[] memory parameters = new Spf.SpfParameter[](4);
        parameters[0] = Spf.createPlaintextParameter(64, 0); // zero
        parameters[1] = amount;
        parameters[2] = balance;
        parameters[3] = Spf.createOutputCiphertextParameter(64); // updatedBalance

        Spf.SpfRunHandle runHandle = Spf.requestSpf(PRIMUS_TIP_SPF_LIBRARY, PRIMUS_ADD_TO_BALANCE_PROGRAM, parameters);

        Spf.SpfParameter memory updatedBalance = Spf.getOutputHandle(runHandle, 0);

        return updatedBalance;
    }

    /**
     * Withdraw the specified amount from the user's balance.
     *
     * @param amount The amount to withdraw (plaintext).
     * @param balance The current balance of the user (encrypted).
     * @return updatedAmount The updated amount after the withdrawal (encrypted).
     * @return updatedBalance The updated balance after the withdrawal (encrypted).
     */
    function withdraw(uint64 amount, Spf.SpfParameter memory balance)
        internal
        returns (Spf.SpfParameter memory, Spf.SpfParameter memory)
    {
        Spf.SpfParameter[] memory parameters = new Spf.SpfParameter[](5);
        parameters[0] = Spf.createPlaintextParameter(64, 0); // zero
        parameters[1] = Spf.createPlaintextParameter(64, amount); // amount to withdraw
        parameters[2] = balance;
        parameters[3] = Spf.createOutputCiphertextParameter(64); // updatedAmount
        parameters[4] = Spf.createOutputCiphertextParameter(64); // updatedBalance

        Spf.SpfRunHandle runHandle = Spf.requestSpf(PRIMUS_TIP_SPF_LIBRARY, PRIMUS_WITHDRAW_PROGRAM, parameters);

        Spf.SpfParameter memory updatedAmount = Spf.getOutputHandle(runHandle, 0);
        Spf.SpfParameter memory updatedBalance = Spf.getOutputHandle(runHandle, 1);

        return (updatedAmount, updatedBalance);
    }
}

/**
 * @title PrimusFHETip
 *
 * A contract for tipping using Primus FHE, allowing users to deposit and tip
 * with encrypted amounts. Users can deposit ERC20 or native tokens, tip
 * recipients with encrypted amounts, and claim tips using attestation from a
 * specified id source.
 *
 * @notice All values in this contract are represented with 64 bits of precision. For
 *   ERC20 tokens with 6 decimal places (for example, stablecoins such as USDT and
 *   USDC), values can be represented normally. However, native tokens (which have
 *   18 decimal places) are represented in gwei (1 gwei = 10^9 wei) to ensure real
 *   world token amounts can be represented accurately. As a consequence, all
 *   native token amounts must be whole gwei amounts (i.e., divisible evenly by
 *   10^9 wei).
 */
contract PrimusFHETip is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, TfheThresholdDecryption {
    using StringUtils for string;
    using JsonParser for string;
    using Currency for uint256;

    /// Represents a token withdraw request that is handled by the decryption
    /// service.
    struct WithdrawToken {
        address recipient;
        TipToken token;
        bool processed;
    }

    /// When a tipper deposits tokens (in plaintext) into the contract, this event is emitted.
    event DepositEvent(address indexed depositor, TipToken token, uint64 depositAmount, uint64 depositTime);

    /// When a tipper tips a recipient, this (encrypted) event is emitted.
    event EncryptedTipEvent(
        string idSource,
        string id,
        address tipper,
        address tokenAddr,
        Spf.SpfParameter amountId,
        uint64 tipTime,
        uint32 tokenType
    );

    /// When a recipient claims their tips, this (encrypted) event is emitted.
    event ClaimEvent(
        address indexed recipient,
        uint64 claimTime,
        string idSource,
        string id,
        address tipper,
        address tokenAddr,
        Spf.SpfParameter amountId,
        uint64 tipTime,
        uint32 tokenType
    );

    /// When a recipient withdraws their claimed tokens, this (plaintext) event is emitted.
    event WithdrawEvent(address indexed recipient, uint64 withdrawTime, uint256 amount);

    // IPrimusZKTLS contract
    IPrimusZKTLS public primusZKTLS;

    /// Constant fee per tip for claiming tips, paid by the claimer.
    uint256 public claimFee;

    /// The fee recipient address where the claim fees are sent.
    address public feeRecipient;

    /// The web2 ID source and JSON path for an account, cached.
    mapping(string => IdSource) public idSourceCache;

    /// Tip records by idSource and id
    mapping(string => mapping(string => EncryptedTipRecord[])) private tipRecords;

    /// Claimed ERC20 and native token balances for recipient.
    mapping(address => Spf.SpfParameter) public erc20ClaimedBalance;
    mapping(address => Spf.SpfParameter) public nativeClaimedBalance;

    /// Tipper deposits of ERC20 tokens.
    mapping(address => uint256) private erc20Deposits;

    /// Tipper spent amounts of ERC20 tokens.
    mapping(address => Spf.SpfParameter) private erc20Spent;

    /// Tipper deposits of native tokens (in gwei).
    mapping(address => uint256) private nativeDeposits;

    /// Tipper spent amounts of native tokens (in gwei).
    mapping(address => Spf.SpfParameter) private nativeSpent;

    /// Mapping between the requested encrypted amount to withdraw and the token
    /// details needed when the callback function executes.
    mapping(bytes32 => WithdrawToken) private decryptionWithdrawToken;

    uint256 gasCost;

    ////////////////////////////////////////////////////////////////////////
    // Views into contract storage                                        //
    ////////////////////////////////////////////////////////////////////////

    /**
     * Get the claimed balance of the user for ERC20 tokens (encrypted)
     */
    function erc20ClaimedBalanceOf(address user) external view returns (Spf.SpfParameter memory) {
        return erc20ClaimedBalance[user];
    }

    /**
     * Get the claimed balance of the user for native tokens (encrypted)
     */
    function nativeClaimedBalanceOf(address user) external view returns (Spf.SpfParameter memory) {
        return nativeClaimedBalance[user];
    }

    /**
     * Get the tips by id and id source of recipient.
     */
    function getTipRecords(TipRecipient calldata tipRecipient) external view returns (EncryptedTipRecord[] memory) {
        return tipRecords[tipRecipient.idSource][tipRecipient.id];
    }

    ////////////////////////////////////////////////////////////////////////
    // Modifiers                                                          //
    ////////////////////////////////////////////////////////////////////////

    /**
     * Modifier to check if the token type is valid.
     * Only supports ERC20 and native tokens.
     *
     * @param token The tip token to check.
     */
    modifier isValidEncryptedTokenType(TipToken memory token) {
        require(
            token.tokenType == ERC20_TYPE || token.tokenType == NATIVE_TYPE,
            "Not supported token type. Only support ERC20 and native tokens"
        );
        _;
    }

    ////////////////////////////////////////////////////////////////////////
    // Utlities                                                           //
    ////////////////////////////////////////////////////////////////////////

    /**
     * Calculates the gas cost for the decryption oracle.
     *
     * @param gas The gas cost for the decryption oracle. If negative, it will be set
     *            to the default for Monad, which always costs 50 gwei per gas.
     * @return The gas cost in wei.
     */
    function calculateGasCost(int256 gas) internal pure returns (uint256) {
        // If the gas cost is negative, we set it to the default for Monad,
        // which always costs 50 gwei per gas. The callback expects to use
        // 100,000 gas.

        return gas < 0 ? 100000 * 50 gwei : uint256(gas);
    }

    ////////////////////////////////////////////////////////////////////////
    // Constructor                                                        //
    ////////////////////////////////////////////////////////////////////////

    /**
     * Initialize function to set the owner of the contract. This function is
     * called during the contract deployment.
     *
     * @param owner The contract owner.
     * @param primusZKTLS_ The IPrimusZKTLS contract address.
     * @param feeRecipient_ The fee recipient address.
     * @param claimFee_ The claim fee.
     * @param gasCost_ The gas cost for the decryption oracle. If negative, it will be set
     *        to the default for Monad.
     */
    function initialize(
        address owner,
        IPrimusZKTLS primusZKTLS_,
        address feeRecipient_,
        uint256 claimFee_,
        int256 gasCost_
    ) public initializer {
        __Ownable_init(owner);

        // Set up the library contract locations
        primusZKTLS = primusZKTLS_;

        // Set the fee recipient and claim fee
        feeRecipient = feeRecipient_;
        claimFee = claimFee_;

        // If the gas cost is negative, we set it to the default for Monad,
        // which always costs 50 gwei per gas. The callback expects to use
        // 100,000 gas.
        gasCost = calculateGasCost(gasCost_);
    }

    ////////////////////////////////////////////////////////////////////////
    // onlyOwner functions                                                //
    ////////////////////////////////////////////////////////////////////////

    /**
     * Add the id attestation source in batch.
     *
     * @param sourceName_ The names of the id sources.
     * @param url_ The URLs of the id sources.
     * @param jsonPath_ The JSON paths to the id sources.
     */
    function addBatchIdSource(string[] memory sourceName_, string[] memory url_, string[] memory jsonPath_)
        external
        onlyOwner
    {
        require(sourceName_.length == url_.length && url_.length == jsonPath_.length, "length not match");
        for (uint256 i = 0; i < sourceName_.length; i++) {
            idSourceCache[sourceName_[i]] = IdSource({url: url_[i], jsonPath: jsonPath_[i]});
        }
    }

    /**
     * Set the fee recipient address.
     *
     * @param feeRecipient_ The fee recipient address.
     */
    function setFeeRecipient(address feeRecipient_) external onlyOwner {
        feeRecipient = feeRecipient_;
    }

    /**
     *  Set IPrimusZKTLS contract instance
     *
     *  @param primusZKTLS_ The address of the IPrimusZKTLS contract
     */
    function setPrimusZKTLS(IPrimusZKTLS primusZKTLS_) external onlyOwner {
        primusZKTLS = primusZKTLS_;
    }

    /**
     *  Set claim fee
     *
     *  @param claimFee_ The submission fee
     */
    function setClaimFee(uint256 claimFee_) external onlyOwner {
        claimFee = claimFee_;
    }

    /**
     * @dev Set the gas cost for the decryption oracle.
     * @param gasCost_ The gas cost for the decryption oracle.
     */
    function setGasCost(int256 gasCost_) external onlyOwner {
        // If the gas cost is negative, we set it to the default for Monad,
        // which always costs 50 gwei per gas. The callback expects to use
        // 100,000 gas.
        gasCost = calculateGasCost(gasCost_);
    }

    ////////////////////////////////////////////////////////////////////////
    // Deposit related functions                                          //
    ////////////////////////////////////////////////////////////////////////

    /**
     * Deposit the token to the contract. Tipper can deposit both erc20 and native tokens.
     *
     * Note: The native token must be a whole gwei amount (i.e., divisible evenly by 10^9 wei).
     *
     * @param token The tip token.
     * @param depositAmount The amount of token to deposit.
     */
    function deposit(TipToken calldata token, uint256 depositAmount) external payable nonReentrant {
        // Deposit the token to the contract.
        _deposit(token, depositAmount);
    }

    /**
     * Deposit the token to the contract. Tipper can deposit both erc20 and native tokens.
     *
     * @notice The native token must be a whole gwei amount (i.e., divisible evenly by 10^9 wei).
     * @notice This variant does not check for re-entrancy, so it should only be used
     *         internally by the contract.
     *
     * @param token The tip token.
     * @param depositAmount The amount of token to deposit.
     */
    function _deposit(TipToken memory token, uint256 depositAmount) internal isValidEncryptedTokenType(token) {
        require(depositAmount > 0, "amount is zero");
        if (token.tokenType == ERC20_TYPE) {
            require(token.tokenAddress != address(0), "error token addr");

            // Check that the value fits in a uint64. The SPF library uses
            // uint64 for amounts.
            require(
                depositAmount + erc20Deposits[msg.sender] <= type(uint64).max,
                "total deposit exceeds the size of a uint64"
            );
        } else if (token.tokenType == NATIVE_TYPE) {
            // Check that the value fits in a uint64. The SPF library uses
            // uint64 for amounts.
            require(
                depositAmount.weiToGweiChecked() + nativeDeposits[msg.sender] <= type(uint64).max,
                "total deposit exceeds the size of a uint64"
            );

            token.tokenAddress = address(0);
        }

        _transferDepositToContract(msg.sender, token, depositAmount, token.tokenType);

        // After the transfer is successful we credit the deposit.
        if (token.tokenType == ERC20_TYPE) {
            erc20Deposits[msg.sender] += depositAmount;
        } else if (token.tokenType == NATIVE_TYPE) {
            // Deposits are stored in amount of gwei
            nativeDeposits[msg.sender] += depositAmount.weiToGweiChecked();
        }

        emit DepositEvent(msg.sender, token, uint64(depositAmount), uint64(block.timestamp));
    }

    /**
     * Transfer the token from the user to the contract.
     *
     * @param from The token sender.
     * @param token The tip token.
     * @param amount The token amount.
     */
    function _transferDepositToContract(address from, TipToken memory token, uint256 amount, uint32 tokenType)
        internal
    {
        if (tokenType == ERC20_TYPE) {
            bool ret = IERC20(token.tokenAddress).transferFrom(from, address(this), amount);
            require(ret, "transfer token fail");
        } else if (tokenType == NATIVE_TYPE) {
            require(msg.value >= amount, "Insufficient token");

            // Transfer back the excess native token to the sender
            uint256 excess = msg.value - amount;
            payable(msg.sender).transfer(excess);
        }
    }

    ////////////////////////////////////////////////////////////////////////
    // Tip related functions                                              //
    ////////////////////////////////////////////////////////////////////////

    /**
     * Tipper tips tokens to the recipient. These can either be ERC20
     * tokens or native tokens.
     *
     * @param token The tip token.
     * @param recipient The recipient information; includes encrypted tip amount.
     */
    function tip(TipToken calldata token, EncryptedTipRecipientInfo calldata recipient) external payable nonReentrant {
        // Tipper tips the token to the recipient.
        _tip(token, recipient);
    }

    /**
     * Tipper tips tokens to the recipient. These can either be ERC20
     * tokens or native tokens.
     *
     * @notice This function does not check for re-entrancy, so it should only be used
     *         internally by the contract.
     *
     * @param token The tip token.
     * @param recipient The recipient information; includes encrypted tip amount.
     */
    function _tip(TipToken calldata token, EncryptedTipRecipientInfo calldata recipient)
        internal
        isValidEncryptedTokenType(token)
    {
        require(!recipient.id.equals(""), "id is empty");
        require(bytes(idSourceCache[recipient.idSource].url).length > 0, "id source not exist");

        // Check if the tipper has the money to spend. If not, then the
        // encrypted tip amount will be modified to be zero.
        Spf.SpfParameter memory amountId = updateTipAmount(token, recipient.amountId);

        EncryptedTipRecord memory tipRecord = EncryptedTipRecord({
            amountId: amountId,
            tipToken: token,
            tipper: msg.sender,
            timestamp: uint64(block.timestamp)
        });
        tipRecords[recipient.idSource][recipient.id].push(tipRecord);

        emit EncryptedTipEvent(
            recipient.idSource,
            recipient.id,
            msg.sender,
            token.tokenAddress,
            recipient.amountId,
            uint64(block.timestamp),
            token.tokenType
        );
    }

    /**
     * Updates the spent amount for the tipper based on the token type.
     * If the tipper has not tipped before, initializes the spent amount to 0.
     * If the tipper does not have enough balance to tip, the encrypted amount is set to 0.
     *
     * @param token The tip token.
     * @param amount The amount to tip (encrypted).
     * @return spentAmount The updated tip amount, having checked that the tipper has enough balance.
     */
    function updateTipAmount(TipToken calldata token, Spf.SpfParameter calldata amount)
        internal
        returns (Spf.SpfParameter memory)
    {
        Spf.SpfParameter memory updatedTip;

        if (token.tokenType == ERC20_TYPE) {
            // If the user has not tipped before, initialize the spent amount to 0.
            if (Spf.isUninitializedParameter(erc20Spent[msg.sender])) {
                erc20Spent[msg.sender] = Spf.createTrivialZeroCiphertextParameter(64);
            }

            // Update the tip amount and spent amount for the user using the SPF
            // off-chain service.
            (Spf.SpfParameter memory updatedAmount, Spf.SpfParameter memory updatedBalance) =
                PrimusSpf.updateTip(amount, erc20Deposits[msg.sender], erc20Spent[msg.sender]);

            // Update the spent amount in the mapping.
            erc20Spent[msg.sender] = updatedBalance;
            updatedTip = updatedAmount;
        } else if (token.tokenType == NATIVE_TYPE) {
            // If the user has not tipped before, initialize the spent amount to 0.
            if (Spf.isUninitializedParameter(nativeSpent[msg.sender])) {
                nativeSpent[msg.sender] = Spf.createTrivialZeroCiphertextParameter(64);
            }

            // Update the tip amount and spent amount for the user using the SPF
            // off-chain service.
            (Spf.SpfParameter memory updatedAmount, Spf.SpfParameter memory updatedBalance) =
                PrimusSpf.updateTip(amount, nativeDeposits[msg.sender], nativeSpent[msg.sender]);

            // Update the spent amount in the mapping.
            nativeSpent[msg.sender] = updatedBalance;
            updatedTip = updatedAmount;
        }

        return updatedTip;
    }

    /**
     * Deposit the token and tip the recipient in one transaction.
     * This is useful for users who want to deposit and tip in one go.
     *
     * @param token The tip token.
     * @param recipient The recipient information; includes encrypted tip amount.
     * @param depositAmount The amount of token to deposit.
     */
    function depositAndTip(TipToken calldata token, EncryptedTipRecipientInfo calldata recipient, uint256 depositAmount)
        external
        payable
        nonReentrant
        isValidEncryptedTokenType(token)
    {
        // Deposit the token first. This will check for a valid token type.
        _deposit(token, depositAmount);

        // Then tip the recipient. This will also check for a valid token type.
        _tip(token, recipient);
    }

    ////////////////////////////////////////////////////////////////////////
    // Claim related functions                                            //
    ////////////////////////////////////////////////////////////////////////

    /**
     * Recipient claims the tip tokens by the id source and attestation.
     *
     * @param idSource The id source of the recipient.
     * @param att The attestation of the recipient.
     */
    function claimBySource(string calldata idSource, Attestation calldata att) external payable nonReentrant {
        // Recipient claims the tip tokens by the id source.
        _claimBySource(idSource, att);
    }

    /**
     * Recipient claims the tip tokens by the id source.
     *
     * @param idSource The id source of the recipient.
     * @param att The attestation of the recipient.
     */
    function _claimBySource(string calldata idSource, Attestation calldata att) internal {
        uint256 count = _performClaimAndBalanceTransfer(idSource, att);
        uint256 amount = claimFee * count;
        require(msg.value >= amount, "Insufficient fee");

        // charge fee for all claimed tips.
        _chargeFee(amount);
        if (msg.value > amount) {
            payable(msg.sender).transfer(msg.value - amount);
        }
    }

    /**
     * Recipient claims the tip tokens by the id.
     *
     * @param idSource The id source of the recipient.
     * @param att The attestation of the recipient.
     * @return The number of tips claimed.
     */
    function _performClaimAndBalanceTransfer(string calldata idSource, Attestation calldata att)
        internal
        returns (uint256)
    {
        string memory id = _checkClaim(idSource, att);
        EncryptedTipRecord[] memory sourceTipRecords = tipRecords[idSource][id];
        require(sourceTipRecords.length > 0, "no claim token");

        // We are going to claim all the tips for this idSource and id, so we
        // delete the record from the mapping.
        delete tipRecords[idSource][id];
        for (uint256 i = 0; i < sourceTipRecords.length; i++) {
            EncryptedTipRecord memory record = sourceTipRecords[i];

            _transferClaimedTokenToRecipient(att.recipient, record.tipToken, record.amountId);
            emit ClaimEvent(
                att.recipient,
                (uint64)(block.timestamp),
                idSource,
                id,
                record.tipper,
                record.tipToken.tokenAddress,
                record.amountId,
                record.timestamp,
                record.tipToken.tokenType
            );
        }
        return sourceTipRecords.length;
    }

    /**
     * Check a specific claim by id source and attestation.
     *
     * @param idSource The id source of the recipient.
     * @param att The attestation of the recipient.
     */
    function _checkClaim(string calldata idSource, Attestation calldata att) internal view returns (string memory) {
        string memory urlStr = idSourceCache[idSource].url;
        require(bytes(urlStr).length > 0, "id source not exist");
        require(att.recipient != address(0), "to addr zero");
        require(att.reponseResolve.length > 0, "No response key");

        primusZKTLS.verifyAttestation(att);
        string memory sourceStr = StringUtils.extractBaseUrl(att.request.url);
        require(urlStr.equals(sourceStr), "id source not match");
        require(att.reponseResolve.length == 1, "reponseResolve not equal 1");
        string memory parsePath = att.reponseResolve[0].parsePath;
        require(parsePath.equals(idSourceCache[idSource].jsonPath), "json path not match");
        string memory conditionOp = att.attConditions.extractValue("op");
        require(conditionOp.equals("STREQ"), "op not match");

        string memory id = att.attConditions.extractValue("value");
        return id;
    }

    /**
     * Charge the claimer per tip claimed.
     *
     * @param fee The fee amount.
     */
    function _chargeFee(uint256 fee) internal {
        if (fee > 0) {
            (bool sent,) = feeRecipient.call{value: fee}("");
            require(sent, "Failed to send fee");
        }
    }

    /**
     * Transfer the claimed token to the recipient.
     *
     * @param to The token recipient.
     * @param token The tip token.
     * @param amount The token amount.
     */
    function _transferClaimedTokenToRecipient(address to, TipToken memory token, Spf.SpfParameter memory amount)
        internal
        isValidEncryptedTokenType(token)
    {
        // We do not need to actually need to check that we can transfer in the
        // token because we know we already have it (was accounted for spending
        // on the tip side)
        if (token.tokenType == ERC20_TYPE) {
            // If the balance was uninitialized, we set it to 0.
            if (Spf.isUninitializedParameter(erc20ClaimedBalance[to])) {
                erc20ClaimedBalance[to] = Spf.createTrivialZeroCiphertextParameter(64);
            }

            // Update the balance of the recipient by adding the amount to the
            // existing balance. Uses the SPF off-chain service to perform the
            // addition.
            Spf.SpfParameter memory updatedBalance = PrimusSpf.addToBalance(amount, erc20ClaimedBalance[to]);

            // Update the encrypted balance of the recipient.
            erc20ClaimedBalance[to] = updatedBalance;
        } else if (token.tokenType == NATIVE_TYPE) {
            // If the balance was uninitialized, we set it to 0.
            if (Spf.isUninitializedParameter(nativeClaimedBalance[to])) {
                nativeClaimedBalance[to] = Spf.createTrivialZeroCiphertextParameter(64);
            }

            // Update the balance of the recipient by adding the amount to the
            // existing balance. Uses the SPF off-chain service to perform the
            // addition.
            Spf.SpfParameter memory updatedBalance = PrimusSpf.addToBalance(amount, nativeClaimedBalance[to]);

            // Update the encrypted balance of the recipient.
            nativeClaimedBalance[to] = updatedBalance;
        }
    }

    ////////////////////////////////////////////////////////////////////////
    // Recipient withdraw functions                                       //
    ////////////////////////////////////////////////////////////////////////

    /**
     * Recipient withdraws the claimed tokens. The recipient must pay the gas
     * cost for the decryption oracle.
     *
     * The amount is in plaintext; if the user does not have enough in their
     * encrypted balance, then the final transfer amount is zero.
     *
     * @param token The tip token.
     * @param amount The amount of token to withdraw (in plaintext).
     */
    function withdraw(TipToken calldata token, uint256 amount) external payable nonReentrant {
        // Recipient withdraws the claimed tokens.
        _withdraw(token, amount);
    }

    /**
     * Recipient withdraws the claimed tokens. The recipient must pay the gas
     * cost for the decryption oracle.
     *
     * The amount is in plaintext; if the user does not have enough in their
     * encrypted balance, then the final transfer amount is zero.
     *
     * @notice This function does not check for re-entrancy, so it should only be used
     *         internally by the contract.
     *
     * @param token The tip token.
     * @param amount The amount of token to withdraw (in plaintext).
     */
    function _withdraw(TipToken memory token, uint256 amount) internal isValidEncryptedTokenType(token) {
        require(amount > 0, "amount is zero");

        if (token.tokenType == NATIVE_TYPE) {
            amount = amount.weiToGweiChecked();
        }

        // Pay the gas cost for the decryption oracle before proceeding with the withdrawal.
        require(msg.value >= gasCost, "The withdrawer must pay the gas cost for the decryption oracle");
        payable(TfheThresholdDecryption.THRESHOLD_DECRYPTION_SERVICE).transfer(gasCost);

        Spf.SpfParameter memory balance =
            token.tokenType == ERC20_TYPE ? erc20ClaimedBalance[msg.sender] : nativeClaimedBalance[msg.sender];

        // Check that the user has enough balance to withdraw the requested
        // amount. Runs using the SPF off-chain service.
        (Spf.SpfParameter memory updatedAmount, Spf.SpfParameter memory updatedBalance) =
            PrimusSpf.withdraw(uint64(amount), balance);

        // Update the encrypted balance.
        if (token.tokenType == ERC20_TYPE) {
            erc20ClaimedBalance[msg.sender] = updatedBalance;
        } else if (token.tokenType == NATIVE_TYPE) {
            nativeClaimedBalance[msg.sender] = updatedBalance;
        } else {
            revert("Unsupported token type");
        }

        // Decrypt the amount and perform the token transfer to the recipient.
        bytes32 identifier = Spf.passToDecryption(updatedAmount);
        requestThresholdDecryption(this.withdrawTokensCallback.selector, identifier);

        // Update the mapping for the decryption withdraw token. This is used to
        // pass extra information to the callback.
        decryptionWithdrawToken[identifier] = WithdrawToken({recipient: msg.sender, token: token, processed: false});
    }

    /**
     * Callback function that is called by the threshold decryption service
     * when the decryption of the requested amount is complete.
     * This function is called only once per ciphertext.
     *
     * @dev Callbacks have a 100,000 gas limit. This callback costs an average
     *   of 43,622 with a maximum of gas 60,554 according to the test report.
     *
     * @param identifier The ciphertext identifier representing the amount that has been decrypted.
     * @param amount The decrypted amount to withdraw (plaintext).
     */
    function withdrawTokensCallback(bytes32 identifier, uint256 amount) public onlyThresholdDecryption nonReentrant {
        // Extract the withdraw token details from the mapping.
        WithdrawToken memory withdrawToken = decryptionWithdrawToken[identifier];
        require(withdrawToken.recipient != address(0), "Decryption was not called on this identifier yet");

        if (withdrawToken.processed) {
            revert("Decryption already processed for this identifier");
        }

        // Mark the withdraw token as processed to prevent re-entrancy.
        withdrawToken.processed = true;

        // Send the tokens to the recipient.
        _withdrawToken(withdrawToken.recipient, withdrawToken.token, amount);
        delete decryptionWithdrawToken[identifier];

        emit WithdrawEvent(withdrawToken.recipient, (uint64)(block.timestamp), amount);
    }

    /**
     * Transfer the token from the contract to the recipient.
     *
     * @param to The token recipient.
     * @param token The tip token.
     * @param amount The token amount (plaintext).
     */
    function _withdrawToken(address to, TipToken memory token, uint256 amount) internal {
        if (token.tokenType == ERC20_TYPE) {
            IERC20 tipToken = IERC20(token.tokenAddress);
            require(tipToken.transfer(to, amount), "Transfer failed");
        } else if (token.tokenType == NATIVE_TYPE) {
            payable(to).transfer(amount.gweiToWei());
        }
    }
}
