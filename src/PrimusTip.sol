// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { IPrimusZKTLS, Attestation } from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";
import {TipToken, TipRecipientInfo, TipRecipient, TipRecord, IdSource, TipWithdrawInfo} from "./types/Common.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./utils/StringUtils.sol";
import "./utils/JsonParser.sol";

/**
 * @dev The Primus Tip contract is used to manage users’ tip funds.
 *      Tippers can lock funds in contracts, and recipients can claim the tip funds after verifying their identities.
 */
contract PrimusTip is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using StringUtils for string;
    using JsonParser for string;

    event TipEvent(string idSource, string id, address tipper, address tokenAddr, uint256 amount, uint64 tipTime, uint32 tokenType, uint256[] nftIds);
    event ClaimEvent(address indexed recipient, uint64 claimTime, string idSource, string id, address tipper, address tokenAddr, uint256 amount, uint64 tipTime, uint32 tokenType, uint256[] nftIds);
    event WithdrawEvent(uint64 withdrawTime, string idSource, string id, address tipper, address tokenAddr, uint256 amount, uint64 tipTime, uint32 tokenType, uint256[] nftIds);

    // IPrimusZKTLS contract
    IPrimusZKTLS public primusZKTLS;
    // claim fee
    uint256 public claimFee;
    // fee recipient address
    address public feeRecipient;
    // withdraw delay
    uint256 public withdrawDelay;
    // id attestation source cache 
    mapping(string => IdSource) public idSourceCache;
    // Tip records by idSource and id
    mapping(string => mapping(string => TipRecord[])) private _tipRecords;

    uint32 constant ERC20_TYPE = 0;
    uint32 constant NATIVE_TYPE = 1;
    uint32 constant ERC721_TYPE = 2;

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
        withdrawDelay = 30 days;
    }

    
    // ========== external functions ==========
    /**
     * @dev Tipper tip the token to the recipient.
     *      Tipper can tip erc20, NFT and native token.
     *      Tipper tip the native token when the token.tokenName equals to native.
     * @param token The tip token.
     * @param recipient The recipient informations.
     */
    function tip(TipToken memory token, TipRecipientInfo calldata recipient) external payable nonReentrant{
        require(token.tokenType == ERC20_TYPE || token.tokenType == NATIVE_TYPE || token.tokenType == ERC721_TYPE, "error token type");
        require(!recipient.id.equals(""), "id is empty");
        require(bytes(idSourceCache[recipient.idSource].url).length > 0, "id source not exist");

        if (token.tokenType == ERC20_TYPE) {
            require(recipient.amount > 0, "amount is zero");
            require(token.tokenAddress != address(0), "error token addr");
        } else if (token.tokenType == NATIVE_TYPE) {
            require(recipient.amount > 0, "amount is zero");
            token.tokenAddress = address(0);
        } else {
            require(token.tokenAddress != address(0), "error token addr");
            require(recipient.nftIds.length > 0, "nft ids empty");
        }

        _transferFromUser(msg.sender, token, recipient.amount, token.tokenType, recipient.nftIds);

        if (token.tokenType == NATIVE_TYPE && msg.value > recipient.amount) {
            payable(msg.sender).transfer(msg.value - recipient.amount);
        }
        
        TipRecord memory tipRecord = TipRecord({
            amount: recipient.amount,
            nftIds: recipient.nftIds,
            tipToken: token,
            tipper: msg.sender,
            timestamp: (uint64)(block.timestamp)
        });
        _tipRecords[recipient.idSource][recipient.id].push(tipRecord);
        emit TipEvent(recipient.idSource, recipient.id, msg.sender, token.tokenAddress, recipient.amount, (uint64)(block.timestamp), token.tokenType, recipient.nftIds);
    }

    /**
     * @dev Tipper tip the token to the batch recipients.
     *      Tipper can tip erc20, NFT and native token.
     *      Tipper tip the native token when the token.tokenName equals to native.
     * @param token The tip token.
     * @param recipients The recipients informations.
     */
    function tipBatch(TipToken memory token, TipRecipientInfo[] calldata recipients) external payable nonReentrant {
        require(token.tokenType == ERC20_TYPE || token.tokenType == NATIVE_TYPE || token.tokenType == ERC721_TYPE, "error token type");
        if (token.tokenType == ERC20_TYPE) {
            require(token.tokenAddress != address(0), "error token addr");
        } else if (token.tokenType == NATIVE_TYPE) {
            token.tokenAddress = address(0);
        } else {
            require(token.tokenAddress != address(0), "error token addr");
        }
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            require(bytes(idSourceCache[recipients[i].idSource].url).length > 0, "id source not exist");
            require(!recipients[i].id.equals(""), "one id is empty");
            if (token.tokenType != ERC721_TYPE) {
                totalAmount += recipients[i].amount;
            } else {
                require(recipients[i].nftIds.length > 0, "nft ids empty");
                _transferFromUser(msg.sender, token, 0, token.tokenType, recipients[i].nftIds);
            }
        }
        if (token.tokenType != ERC721_TYPE) {
            require(totalAmount > 0, "amount is zero");
            uint256[] memory emptyNftIds = new uint256[](0);
            _transferFromUser(msg.sender, token, totalAmount, token.tokenType, emptyNftIds);
        }

        if (token.tokenType == NATIVE_TYPE && msg.value > totalAmount) {
            uint256 rebate = msg.value - totalAmount;
            payable(msg.sender).transfer(rebate);
        }

        for (uint256 i = 0; i < recipients.length; i++) {
            TipRecord memory tipRecord = TipRecord({
                amount: recipients[i].amount,
                nftIds: recipients[i].nftIds,
                tipToken: token,
                tipper: msg.sender,
                timestamp: (uint64)(block.timestamp)
            });
            _tipRecords[recipients[i].idSource][recipients[i].id].push(tipRecord);
            emit TipEvent(recipients[i].idSource, recipients[i].id, msg.sender, token.tokenAddress, recipients[i].amount, (uint64)(block.timestamp), token.tokenType, recipients[i].nftIds);
        }
    }

    /**
     * @dev Recipient claims the tip tokens by the id source.
     */
    function claimBySource(string calldata idSource, Attestation calldata att) external payable nonReentrant {
        uint256 count = _claimBySource(idSource, att);
        uint256 amount = claimFee * count;
        require(msg.value >= amount, "Insufficient fee");
        // charge fee by Source
        _chargeFee(amount);
        if (msg.value > amount) {
            payable(msg.sender).transfer(msg.value - amount);
        }
    }

    /**
     * @dev Recipient claims the tip tokens by id sources.
     */
    function claimByMultiSource(string[] calldata idSources, Attestation[] calldata att) external payable nonReentrant {
        require(idSources.length == att.length, "length not match");
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < idSources.length; i++) {
            uint256 count = _claimBySource(idSources[i], att[i]);
            uint256 amount = claimFee * count;
            totalAmount += amount;
        }

        // charge fee by Source
        require(msg.value >= totalAmount, "Insufficient fee");
        _chargeFee(totalAmount);

        if (msg.value > totalAmount) {
            payable(msg.sender).transfer(msg.value - totalAmount);
        }
    }

    /**
     * @dev The tipper withdraws tokens that have not been claimed within the specified time period.
     */
    function tipperWithdraw(TipWithdrawInfo[] calldata tipRecipients) external nonReentrant {
        bool isWithdrawn = false;
        for (uint256 i = 0; i < tipRecipients.length; i++) {
            TipRecord[] storage records = _tipRecords[tipRecipients[i].idSource][tipRecipients[i].id];
            uint256 j = 0;
            while (j < records.length) {
                TipRecord memory tipRecord = records[j];
                if (msg.sender == tipRecord.tipper && tipRecord.timestamp == tipRecipients[i].tipTimestamp && isExpired(tipRecord.timestamp)) {
                     // Remove records
                    records[j] = records[records.length - 1];
                    records.pop();

                    _transferToken(tipRecord.tipper, tipRecord.tipToken, tipRecord.amount, tipRecord.nftIds);
                    isWithdrawn = true;
                    emit WithdrawEvent((uint64)(block.timestamp), tipRecipients[i].idSource, tipRecipients[i].id, tipRecord.tipper, tipRecord.tipToken.tokenAddress, tipRecord.amount, tipRecord.timestamp, tipRecord.tipToken.tokenType, tipRecord.nftIds);
                } else {
                    j++;
                }
            }
        }
        require(isWithdrawn, "no pending withdrawals");
    }

    /**
     * @dev Get the tip tokens by id and id source of recipient.
     */
    function getTipRecords(TipRecipient calldata tipRecipient) external view returns (TipRecord[] memory) {
        return _tipRecords[tipRecipient.idSource][tipRecipient.id];
    }


    // ========== external onlyOwner functions ==========
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
        }
    }

     /**
     * @dev Set the fee recipient address.
     * @param feeRecipient_ The fee recipient address.
    */
    function setFeeRecipient(address feeRecipient_) external onlyOwner {
        feeRecipient = feeRecipient_;
    }

    /**
     * @dev set the withdraw delay.
     * @param delay The withdraw delay Unit should be days.
    */
    function setWithdrawDelay(uint256 delay) external onlyOwner {
        withdrawDelay = delay;
    }
    /**
     *  @dev set IPrimusZKTLS contract instance
     *  @param primusZKTLS_ The address of the IPrimusZKTLS contract
     */
    function setPrimusZKTLS(IPrimusZKTLS primusZKTLS_) external onlyOwner {
        primusZKTLS = primusZKTLS_;
    }

    /**
     *  @dev set claim fee
     *  @param claimFee_ The submission fee
     */
    function setClaimFee(uint256 claimFee_) external onlyOwner {
        claimFee = claimFee_;
    }


     // ========== internal functions ==========

    /**
     * @dev Check attestaion.
     * @param idSource The id source of the recipient.
     * @param att The attestation of the recipient.
     */
    function _checkClaim(string calldata idSource, Attestation calldata att) internal view returns (string memory) {
        string memory urlStr = idSourceCache[idSource].url;
        require(bytes(urlStr).length > 0, "id source not exist");
        require(att.recipient != address(0), "to addr zero");
        require(att.reponseResolve.length > 0, "No response key");

        primusZKTLS.verifyAttestation(att);
        string memory sourceStr = extractBaseUrl(att.request.url);
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
     * @dev Recipient claims the tip tokens by the id.
     * @param idSource The id source of the recipient.
     * @param att The attestation of the recipient.
     */
    function _claimBySource(string calldata idSource, Attestation calldata att) internal returns (uint256) {
        string memory id = _checkClaim(idSource, att);
        TipRecord[] memory tipRecords = _tipRecords[idSource][id];
        require(tipRecords.length > 0, "no claim token");

        delete _tipRecords[idSource][id];
        for (uint256 i = 0; i < tipRecords.length; i++) {
            TipRecord memory record = tipRecords[i];
            _transferToken(att.recipient, record.tipToken, record.amount, record.nftIds);
            emit ClaimEvent(att.recipient, (uint64)(block.timestamp), idSource, id, record.tipper, record.tipToken.tokenAddress, record.amount, record.timestamp, record.tipToken.tokenType, record.nftIds);
        }
        return tipRecords.length;
    }

    /**
     * @dev Transfer the token from the user to the contract.
     * @param from The token sender.
     * @param token The tip token.
     * @param amount The token amount.
    */
    function _transferFromUser(address from, TipToken memory token, uint256 amount, uint32 tokenType, uint256[] memory nftIds) internal {
        if (tokenType == ERC20_TYPE) {
            IERC20 tipToken = IERC20(token.tokenAddress);
            bool ret = tipToken.transferFrom(from, address(this), amount);
            require(ret, "transfer token fail");
        } else if (tokenType == NATIVE_TYPE) {
            require(msg.value >= amount, "Insufficient token");
        } else {
            IERC721 tipToken = IERC721(token.tokenAddress);
            for (uint256 i = 0; i < nftIds.length; i++) {
                tipToken.transferFrom(from, address(this), nftIds[i]);
            }
        }
    }

    /**
     * @dev Transfer the token from the contract to the user.
     * @param to The token recipient.
     * @param token The tip token.
     * @param amount The token amount.
    */
    function _transferToken(address to, TipToken memory token, uint256 amount, uint256[] memory nftIds) internal {
        if (token.tokenType == ERC20_TYPE) {
            IERC20 tipToken = IERC20(token.tokenAddress);
            require(tipToken.transfer(to, amount), "Transfer failed");
        } else if (token.tokenType == NATIVE_TYPE) {
            payable(to).transfer(amount);
        } else {
            IERC721 tipToken = IERC721(token.tokenAddress);
            for (uint256 i = 0; i < nftIds.length; i++) {
                tipToken.transferFrom(address(this), to, nftIds[i]);
            }
        }
    }

    /**
     * @dev Charge the fee from the user.
     * @param fee The fee amount.
    */
    function _chargeFee(uint256 fee) internal {
        if (fee > 0) {
            // payable(feeRecipient).transfer(fee);
            (bool sent,) = feeRecipient.call{value: fee}("");
            require(sent, "Failed to send fee");
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
