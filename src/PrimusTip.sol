// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPrimusZKTLS, Attestation } from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";
import {TipToken, TipRecipientInfo, TipRecipient, TipRecord, IdSource} from "./types/Common.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./utils/StringUtils.sol";
import "./utils/JsonParser.sol";

/**
 * @dev The Primus Tip contract is used to manage users’ tip funds.
 *      Tippers can lock funds in contracts, and recipients can claim the tip funds after verifying their identities.
 */
contract PrimusTip is  Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using StringUtils for string;
    using JsonParser for string;

    event TipEvent(string idSource, string id);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event WithdrawDelayChanged(uint256 oldDelay, uint256 newDelay);
    event ClaimEvent(address indexed recipient, string idSource, string id, address tokenAddr, uint256 amount);
    event AddIdSource(string _sourceName, string _url, string _jsonPath);
    event FeeCollected(address indexed payer, address token, uint256 amount);
    event WithdrawEvent(address indexed tipper, address indexed tokenAddr, uint256 amount);
    event ClaimFeeSet(uint256 indexed fee);
    event SetPrimusZKTLS(address indexed primusZKTLS);
    event RebateBalance(address indexed recipient, uint256 amount);

    // IPrimusZKTLS contract
    IPrimusZKTLS public primusZKTLS;
    // claim fee
    uint256 public claimFee;
    // fee recipient address
    address public feeRecipient;
    // withdraw delay
    uint256 public withdrawDelay = 30 days;
    // id attestation source cache 
    mapping(string => IdSource) public idSourceCache;
    // Tip records by idSource and id
    mapping(string => mapping(string => TipRecord[])) private _tipRecords;

    uint32 constant ERC20_TYPE = 0;
    uint32 constant NATIVE_TYPE = 1;

    /**
     * @dev Initialize function to set the owner of the contract.
     *      This function is called during the contract deployment.
     * @param owner The contract owner.
     * @param primusZKTLS_ The IPrimusZKTLS contract address.
     * @param feeRecipient_ The fee recipient address.
     * @param claimFee_ The claim fee.
     */
    function initialize(
        address owner,
        IPrimusZKTLS primusZKTLS_,
        address feeRecipient_,
        uint256 claimFee_
    ) public initializer {
        __Ownable_init(owner);
        primusZKTLS = primusZKTLS_;
        feeRecipient = feeRecipient_;
        claimFee = claimFee_;
    }

    
    // ========== external  ==========
    /**
     * @dev Tipper tip the token to the recipient.
     *      Tipper can tip erc20, NFT and native token.
     *      Tipper tip the native token when the token.tokenName equals to native.
     * @param token The tip token.
     * @param recipient The recipient informations.
     */
    function tip(TipToken calldata token, TipRecipientInfo calldata recipient) external payable {
        require(token.tokenType == ERC20_TYPE || token.tokenType == NATIVE_TYPE,"error token type");
        require(recipient.amount > 0, "amount is zero");
        require(!recipient.id.equals(""), "id is empty");
        require(bytes(idSourceCache[recipient.idSource].url).length > 0, "id source not exist");

        if (token.tokenType == ERC20_TYPE) {
            require(token.tokenAddress != address(0), "error token addr");
        }

        _transferFromUser(msg.sender, token, recipient.amount, token.tokenType);

        if (token.tokenType == NATIVE_TYPE && msg.value > recipient.amount) {
            payable(msg.sender).transfer(msg.value - recipient.amount);
            emit RebateBalance(msg.sender, msg.value - recipient.amount);
        }
        
        TipRecord memory tipRecord = TipRecord({
            amount: recipient.amount,
            nftIds: new uint256[](0),
            tipToken: token,
            tipper: msg.sender,
            timestamp: (uint64)(block.timestamp)
        });
        _tipRecords[recipient.idSource][recipient.id].push(tipRecord);
        emit TipEvent(recipient.idSource, recipient.id);
    }

    /**
     * @dev Tipper tip the token to the batch recipients.
     *      Tipper can tip erc20, NFT and native token.
     *      Tipper tip the native token when the token.tokenName equals to native.
     * @param token The tip token.
     * @param recipients The recipients informations.
     */
    function tipBatch(TipToken calldata token, TipRecipientInfo[] calldata recipients) external payable {
        require(token.tokenType == ERC20_TYPE || token.tokenType == NATIVE_TYPE,"error token type");
        if (token.tokenType == ERC20_TYPE) {
            require(token.tokenAddress != address(0), "error token addr");
        }
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            require(bytes(idSourceCache[recipients[i].idSource].url).length > 0, "id source not exist");
            require(!recipients[i].id.equals(""), "one id is empty");
            totalAmount += recipients[i].amount;
        }
        require(totalAmount > 0, "amount is zero");
        _transferFromUser(msg.sender, token, totalAmount, token.tokenType);

        if (token.tokenType == NATIVE_TYPE && msg.value > totalAmount) {
            uint256 rebate = msg.value - totalAmount;
            payable(msg.sender).transfer(rebate);
            emit RebateBalance(msg.sender, rebate);
        }
         
        for (uint256 i = 0; i < recipients.length; i++) {
            TipRecord memory tipRecord = TipRecord({
                amount: recipients[i].amount,
                nftIds: new uint256[](0),
                tipToken: token,
                tipper: msg.sender,
                timestamp: (uint64)(block.timestamp)
            });
            _tipRecords[recipients[i].idSource][recipients[i].id].push(tipRecord);
            emit TipEvent(recipients[i].idSource, recipients[i].id);
        }
    }

    /**
     * @dev Recipient claims the tip tokens by the id source.
     */
    function claimBySource(string calldata idSource, Attestation calldata att) external payable nonReentrant {
        uint256 count = _claimBySource(idSource, att);
        require(count > 0, "no claim token");
        uint256 amount = claimFee*count;
        require(msg.value >= amount, "Insufficient fee");
        // charge fee by Source
        _chargeFee(amount);
    }

    /**
     * @dev Recipient claims the tip tokens by id sources.
     */
    function claimByMultiSource(string[] calldata idSources, Attestation[] calldata att) external payable  {
        require(idSources.length == att.length, "length not match");
        uint256 value = msg.value;
        for (uint256 i = 0; i < idSources.length; i++) {
            uint256 count = _claimBySource(idSources[i], att[i]);
            require(count > 0, "no claim token");
            uint256 amount = claimFee*count;
            uint256 balance = value - amount;
            require(balance >= 0, "Insufficient fee");
            // charge fee by Source
            _chargeFee(amount);
        } 
    }

    /**
     * @dev The tipper withdraws tokens that have not been claimed within the specified time period.
     */
    function tipperWithdraw(TipRecipient[] calldata tipRecipients) external nonReentrant {
        for (uint256 i = 0; i < tipRecipients.length; i++) {
            TipRecord[] storage records = _tipRecords[tipRecipients[i].idSource][tipRecipients[i].id];
            require(records.length > 0, "no pending withdrawals");
            for (uint256 j = 0; j < records.length; j++) {
                TipRecord memory tipRecord = records[j];
                if (isExpired(tipRecord.timestamp)) {
                     // Remove records
                    records[j] = records[records.length - 1];
                    records.pop();

                    _transferToken(tipRecord.tipper, tipRecord.tipToken, tipRecord.amount);
                    emit WithdrawEvent(tipRecord.tipper, tipRecord.tipToken.tokenAddress, tipRecord.amount);
                }
            }
        }
    }

    /**
     * @dev Get the tip tokens by id and id source of recipient.
     */
    function getTipRecords(TipRecipient calldata tipRecipient) external view returns (TipRecord[] memory) {
        return _tipRecords[tipRecipient.idSource][tipRecipient.id];
    }


    /**
     * @dev Add the id attestation source.
     */
    function addIdSource(string memory sourceName_, string memory url_, string memory jsonPath_) external onlyOwner {
        require(bytes(sourceName_).length > 0, "Empty source name");
        require(bytes(idSourceCache[sourceName_].url).length == 0, "Source exists");
        idSourceCache[sourceName_] = IdSource({
            url: url_,
            jsonPath: jsonPath_
        });
        emit AddIdSource(sourceName_, url_, jsonPath_);
    }

    /**
     * @dev Add the id attestation source in batch.
    */
    function addBatchIdSource(string[] memory sourceName_, string[] memory url_, string[] memory jsonPath_) external onlyOwner {
        require(sourceName_.length == url_.length && url_.length == jsonPath_.length, "length not match");
        for (uint256 i = 0; i < sourceName_.length; i++) {
            idSourceCache[sourceName_[i]] = IdSource({
                url: url_[i],
                jsonPath: jsonPath_[i]
            });
            emit AddIdSource(sourceName_[i], url_[i], jsonPath_[i]);
        }
    }

    // ========== public  ==========
     /**
     * @dev Set the fee recipient address.
     * @param feeRecipient_ The fee recipient address.
    */
    function setFeeRecipient(address feeRecipient_) public onlyOwner {
        emit FeeRecipientChanged(feeRecipient, feeRecipient_);
        feeRecipient = feeRecipient_;
    }

    /**
     * @dev set the withdraw delay.
     * @param delay The withdraw delay Unit should be days.
    */
    function setWithdrawDelay(uint256 delay) public onlyOwner {
        emit WithdrawDelayChanged(withdrawDelay, delay);
        withdrawDelay = delay;
    }
    /**
     *  @dev set IPrimusZKTLS contract instance
     *  @param primusZKTLS_ The address of the IPrimusZKTLS contract
     */
    function setPrimusZKTLS(IPrimusZKTLS primusZKTLS_) public onlyOwner {
        primusZKTLS = primusZKTLS_;
        emit SetPrimusZKTLS(address(primusZKTLS_));
    }

    /**
     *  @dev set claim fee
     *  @param claimFee_ The submission fee
     */
    function setClaimFee(uint256 claimFee_) public onlyOwner {
        claimFee = claimFee_;
        emit ClaimFeeSet(claimFee_);
    }

     // ========== internal  ==========
     /**
     * @dev Recipient claims the tip tokens by the id.
     * @param idSource The id source of the recipient.
     * @param att The attestation of the recipient.
     */
    function _claimBySource(string calldata idSource, Attestation calldata att) internal returns (uint256) {
        string memory urlStr = idSourceCache[idSource].url;
        require(bytes(urlStr).length > 0, "id source not exist");
        require(att.recipient != address(0), "to addr zero");
        require(att.reponseResolve.length > 0, "No response key");

        primusZKTLS.verifyAttestation(att);
        string memory sourceStr = extractBaseUrl(att.request.url);
        require(urlStr.equals(sourceStr), "id source not match");

        string memory id = att.data.extractValue(att.reponseResolve[0].keyName);
        TipRecord[] memory tipRecords = _tipRecords[idSource][id];
        require(tipRecords.length > 0, "no claim token");
        string memory parsePath = att.reponseResolve[0].parsePath;
        require(parsePath.equals(idSourceCache[idSource].jsonPath), "json path not match");

        delete _tipRecords[idSource][id];

        for (uint256 i = 0; i < tipRecords.length; i++) {
            TipRecord memory record = tipRecords[i];
            _transferToken(att.recipient, record.tipToken, record.amount);
            emit ClaimEvent(att.recipient, idSource,id, record.tipToken.tokenAddress, record.amount);
        }
        return tipRecords.length;
    }


    /**
     * @dev Transfer the token from the user to the contract.
     * @param from The token sender.
     * @param token The tip token.
     * @param amount The token amount.
    */
    function _transferFromUser(address from, TipToken memory token, uint256 amount, uint32 tokenType) internal {
        if (tokenType == ERC20_TYPE) {
            IERC20 tipToken = IERC20(token.tokenAddress);
            bool ret = tipToken.transferFrom(from, address(this), amount);
            require(ret, "transfer token fail");
        } else if (tokenType == NATIVE_TYPE) {
            require(msg.value >= amount, "Insufficient ETH");
        }
    }

    /**
     * @dev Transfer the token from the contract to the user.
     * @param to The token recipient.
     * @param token The tip token.
     * @param amount The token amount.
    */
    function _transferToken(address to, TipToken memory token, uint256 amount) internal {
        if (token.tokenType == ERC20_TYPE) {
            IERC20 tipToken = IERC20(token.tokenAddress);
            require(tipToken.transfer(to, amount), "Transfer failed");
        } else if (token.tokenType == NATIVE_TYPE) {
            payable(to).transfer(amount);
        }
    }

    /**
     * @dev Charge the fee from the user.
     * @param fee The fee amount.
    */
    function _chargeFee(uint256 fee) internal {
        if (fee > 0) {
            payable(feeRecipient).transfer(fee);
            emit FeeCollected(msg.sender, address(0), fee);
        }
    }

     /**
     * @dev Extract the base URL (ignoring query parameters)
     * @param url The full URL
     * @return The base URL without query parameters
     */
    function extractBaseUrl(string memory url) internal pure returns (string memory) {
        bytes memory urlBytes = bytes(url);
        uint256 queryStart = urlBytes.length;
        for (uint256 i = 0; i < urlBytes.length; i++) {
            if (urlBytes[i] == "?") {
                queryStart = i;
                break;
            }
        }
        bytes memory baseUrlBytes = new bytes(queryStart);
        for (uint256 i = 0; i < queryStart; i++) {
            baseUrlBytes[i] = urlBytes[i];
        }
        return string(baseUrlBytes);
    }

    /**
     * @dev Check if the tip is expired.
     * @param timestamp The timestamp of the tip.
     * @return True if the tip is expired, otherwise false.
    */
    function isExpired(uint256 timestamp) internal view returns (bool) {
        return block.timestamp >= timestamp + withdrawDelay;
    }

}
