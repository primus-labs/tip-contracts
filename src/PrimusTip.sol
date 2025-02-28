// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPrimusZKTLS, Attestation } from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";
import {TipToken, TipRecipientInfo, TipRecipient, TipRecord, IdSource} from "./types/Common.sol";
import "./utils/StringUtils.sol";
import "./utils/JsonParser.sol";
import "forge-std/Test.sol";

import {ReentrancyGuard} from "./utils/ReentrancyGuard.sol";
/**
 * @dev The Primus Tip contract is used to manage users’ tip funds.
 *      Tippers can lock funds in contracts, and recipients can claim the tip funds after verifying their identities.
 */
contract PrimusTip is  Initializable, OwnableUpgradeable {
    using StringUtils for string;
    using JsonParser for string;
    using ReentrancyGuard for ReentrancyGuard.ReentrancyWrapper;

    event TipEvent(string idSource, string id);
    event FeeRecipientChanged(address indexed oldRecipient, address indexed newRecipient);
    event WithdrawDelayChanged(uint256 oldDelay, uint256 newDelay);
    event ClaimEvent(address indexed recipient, address tokenAddr, uint256 amount);
    event AddIdSource(string _sourceName, string _url, string _jsonPath);
    event FeeCollected(address indexed payer, address token, uint256 amount);
    event WithdrawEvent(address indexed tipper, address indexed tokenAddr, uint256 amount);
    event ClaimFeeSet(uint256 indexed fee);
    event SetPrimusZKTLS(address indexed primusZKTLS);

    // IPrimusZKTLS contract
    IPrimusZKTLS public primusZKTLS;
    // claim fee
    uint256 public claimFee;
    address private feeRecipient;
    // withdraw delay
    uint256 public WITHDRAW_DELAY = 30 days;
    // id attestation source cache 
    mapping(string => IdSource) public idSourceCache;
    // Tip records by idSource and id
    mapping(string => mapping(string => TipRecord[])) private _tipRecords;
    // Tip record by tipper address and id
    mapping(address => string[]) private tipperCache;
    // ReentrancyGuard instance
    ReentrancyGuard.ReentrancyWrapper private reentrancy;

    // ReentrancyGuard
    modifier nonReentrant() {
        require(!reentrancy.locked, "ReentrancyGuard: reentrant call");
        reentrancy.locked = true;
        _;
        reentrancy.locked = false;
    }

    /**
     * @dev Initialize function to set the owner of the contract.
     *      This function is called during the contract deployment.
     * @param owner The contract owner.
     * @param _feeRecipient The fee recipient address.
     * @param _primusZKTLS The IPrimusZKTLS contract address.
     */
    function initialize(
        address owner,
        address _feeRecipient, 
        IPrimusZKTLS _primusZKTLS
    ) public initializer {
        __Ownable_init(owner);
        feeRecipient = _feeRecipient;
        primusZKTLS = _primusZKTLS;
    }

    /**
     * 
     * @dev Set the fee recipient address.
     * @param newFeeRecipient The fee recipient address.
    */
    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        emit FeeRecipientChanged(feeRecipient, newFeeRecipient);
        feeRecipient = newFeeRecipient;
    }

    /**
     * @dev set the withdraw delay.
     * @param delay The withdraw delay Unit should be days.
    */
    function setWithdrawDelay(uint256 delay) external onlyOwner {
        emit WithdrawDelayChanged(WITHDRAW_DELAY, delay);
        WITHDRAW_DELAY = delay;
    }

    /**
     * @dev Transfer the token from the user to the contract.
     * @param from The token sender.
     * @param token The tip token.
     * @param amount The token amount.
    */
    function _transferFromUser(address from, TipToken memory token, uint256 amount) internal {
        if (token.tokenType.equals("erc20")) {
            IERC20 tipToken = IERC20(token.tokenAddress);
            uint256 balance = tipToken.balanceOf(from);
            console.log("transferFromUser:balance=%d, amount=%d", balance, amount);
            bool ret = tipToken.transferFrom(from, address(this), amount);
            require(ret, "transfer token fail");
        } else if (token.tokenType.equals("native")) {
            console.log("transfer native token:msg.value=%s, amount=%s", msg.value, amount);
            require(msg.value >= amount, "Insufficient ETH");
            console.log("transfer native token success:msg.value=%s", msg.value);
        }
    }

    /**
     * @dev Transfer the token from the contract to the user.
     * @param to The token recipient.
     * @param token The tip token.
     * @param amount The token amount.
    */
    function _transferToken(address to, TipToken memory token, uint256 amount) internal {
        if (token.tokenType.equals("erc20")) {
            IERC20 tipToken = IERC20(token.tokenAddress);
            require(tipToken.transfer(to, amount), "Transfer failed");
        } else if (token.tokenType.equals("native")) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "ETH transfer failed");
        }
    }

    /**
     * @dev Charge the fee from the user.
     * @param fee The fee amount.
    */
    function _chargeFee(uint256 fee) internal {
        require(msg.value >= fee, "Insufficient fee");
        if (fee > 0) {
            payable(feeRecipient).transfer(fee);
            emit FeeCollected(msg.sender, address(0), fee);
        }
    }

    /**
     * @dev Tipper tip the token to the recipient.
     *      Tipper can tip erc20, NFT and native token.
     *      Tipper tip the native token when the token.tokenName equals to native.
     * @param token The tip token.
     * @param recipient The recipient informations.
     */
    function tip(TipToken calldata token, TipRecipientInfo calldata recipient) external payable {
        require(token.tokenType.equals("erc20") || token.tokenType.equals("native"), "error token type");
        require(recipient.amount > 0, "amount is zero");
        require(!recipient.id.equals(""), "id is empty");
        require(bytes(idSourceCache[recipient.idSource].url).length > 0, "id source not exist");

        _transferFromUser(msg.sender, token, recipient.amount);

        if (token.tokenType.equals("native") && msg.value > recipient.amount) {
            payable(msg.sender).transfer(msg.value - recipient.amount);
        }
        
        TipRecord memory tipRecord = TipRecord({
            tipRecipientInfo: recipient,
            tipToken: token,
            tipper: msg.sender,
            timestamp: block.timestamp
        });
        _tipRecords[recipient.idSource][recipient.id].push(tipRecord);

        string memory cacheKey = string(abi.encodePacked(recipient.idSource, "-", recipient.id));
        if (!contains(tipperCache[msg.sender], cacheKey)) {
            tipperCache[msg.sender].push(cacheKey);
        }
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
        require(token.tokenType.equals("erc20") || token.tokenType.equals("native"), "error token type");
        require(token.tokenAddress != address(0), "error token addr");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            require(bytes(idSourceCache[recipients[i].idSource].url).length > 0, "id source not exist");
        }

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            require(!recipients[i].id.equals(""), "one id is empty");
            totalAmount += recipients[i].amount;
        }
        require(totalAmount > 0, "amount is zero");
        _transferFromUser(msg.sender, token, totalAmount);

        if (token.tokenType.equals("native") && msg.value > totalAmount) {
            payable(msg.sender).transfer(msg.value - totalAmount);
        }
        
        for (uint256 i = 0; i < recipients.length; i++) {
            TipRecord memory tipRecord = TipRecord({
                tipRecipientInfo: recipients[i],
                tipToken: token,
                tipper: msg.sender,
                timestamp: block.timestamp
            });
            _tipRecords[recipients[i].idSource][recipients[i].id].push(tipRecord);
            emit TipEvent(recipients[i].idSource, recipients[i].id);
        }
    }

    /**
     * @dev Recipient claims the tip tokens by the id source.
     */
    function claimBySource(string calldata idSource, Attestation calldata att) public payable nonReentrant {
        require(msg.value >= claimFee, "Insufficient fee");
        _chargeFee(claimFee);

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

        delete _tipRecords[idSource][id];

        for (uint256 i = 0; i < tipRecords.length; i++) {
            TipRecord memory record = tipRecords[i];
            _transferToken(att.recipient, record.tipToken, record.tipRecipientInfo.amount);
            emit ClaimEvent(att.recipient, record.tipToken.tokenAddress, record.tipRecipientInfo.amount);
        }
    }

    /**
     * @dev Recipient claims the tip tokens by id sources.
     */
    function claimByMultiSource(string[] calldata idSources, Attestation[] calldata att) external payable nonReentrant {
        require(idSources.length == att.length, "length not match");
        uint256 totalFee = claimFee * idSources.length;
        _chargeFee(totalFee); 

        for (uint256 i = 0; i < idSources.length; i++) {
            _processClaim(idSources[i], att[i]);
        }
    }

    /**
     * @dev Recipient claims the tip tokens by the id.
     * @param idSource The id source.
     * @param att The attestation.
     */
    function _processClaim(string calldata idSource, Attestation calldata att) internal {
        claimBySource(idSource, att);
    }
    
    /**
     * @dev The tipper withdraws tokens that have not been claimed within the specified time period.
     */
    function tipperWithdraw() external nonReentrant {
        require(tipperCache[msg.sender].length > 0, "No pending withdrawals");

        string[] memory pendingKeys = new string[](tipperCache[msg.sender].length);
        uint256 pendingCount = 0;

        for (uint256 i = 0; i < tipperCache[msg.sender].length; i++) {
            string memory key = tipperCache[msg.sender][i];
            (string memory idSource, string memory id) = splitKey(key);
            TipRecord[] storage records = _tipRecords[idSource][id];
        
            bool hasActiveRecords = false;

            for (uint256 j = records.length; j > 0; ) {
                uint256 index = j - 1;
                TipRecord storage record = records[index];
            
                if (record.tipper == msg.sender && isExpired(record.timestamp)) {
                    // Transfer funds
                    uint256 amount = record.tipRecipientInfo.amount;
                    _transferToken(msg.sender, record.tipToken, amount);
                    emit WithdrawEvent(msg.sender, record.tipToken.tokenAddress, amount);

                    // Remove record
                    if (index != records.length - 1) {
                        records[index] = records[records.length - 1];
                    }
                    records.pop();
                } else {
                    hasActiveRecords = true; 
                }
                j--; 
            }

            // Update cache
            if (hasActiveRecords) {
                pendingKeys[pendingCount] = key;
                pendingCount++;
            } else {
                delete _tipRecords[idSource][id];
                _removeCacheKey(msg.sender, key); 
            }
        }

        // Update tipperCache
        if (pendingCount < tipperCache[msg.sender].length) {
            tipperCache[msg.sender] = pendingKeys;
        }
    }

    function _removeCacheKey(address tipper, string memory key) private {
        for (uint256 i = 0; i < tipperCache[tipper].length; i++) {
         if (keccak256(bytes(tipperCache[tipper][i])) == keccak256(bytes(key))) {
            tipperCache[tipper][i] = tipperCache[tipper][tipperCache[tipper].length - 1];
            tipperCache[tipper].pop();
            break;
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
    function addIdSource(string memory _sourceName, string memory _url, string memory _jsonPath) external onlyOwner {
        require(bytes(_sourceName).length > 0, "Empty source name");
        require(bytes(idSourceCache[_sourceName].url).length == 0, "Source exists");
        idSourceCache[_sourceName] = IdSource({
            url: _url,
            jsonPath: _jsonPath
        });
        emit AddIdSource(_sourceName, _url, _jsonPath);
    }

    /**
     * 
     * @dev Add the id attestation source in batch.
    */
    function addBatchIdSource(string[] memory _sourceName, string[] memory _url, string[] memory _jsonPath) external onlyOwner {
        require(_sourceName.length == _url.length && _url.length == _jsonPath.length, "length not match");
        for (uint256 i = 0; i < _sourceName.length; i++) {
            idSourceCache[_sourceName[i]] = IdSource({
                url: _url[i],
                jsonPath: _jsonPath[i]
            });
            emit AddIdSource(_sourceName[i], _url[i], _jsonPath[i]);
        }
    }


    /**
     *  @dev set IPrimusZKTLS contract instance
     *  @param _primusZKTLS The address of the IPrimusZKTLS contract
     */
    function setPrimusZKTLS(IPrimusZKTLS _primusZKTLS) public onlyOwner {
        primusZKTLS = _primusZKTLS;
        emit SetPrimusZKTLS(address(_primusZKTLS));
    }

    /**
     *  @dev set claim fee
     *  @param _claimFee The submission fee
     */
    function setClaimFee(uint256 _claimFee) public onlyOwner {
        claimFee = _claimFee;
        emit ClaimFeeSet(_claimFee);
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
        return block.timestamp >= timestamp + 30 days;
    }

    /**
     * @dev Check if the value is in the array.
     * @param array The array to check.
     * @param value The value to check.
     * @return True if the value is in the array, otherwise false.
    */
    function contains(string[] storage array, string memory value) internal view returns (bool) {
        for (uint256 i = 0; i < array.length; i++) {
            if (keccak256(abi.encodePacked(array[i])) == keccak256(abi.encodePacked(value))) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev Split the key into id and id source.
     * @param key The key to split.
     * @return The id and id source.
    */
    function splitKey(string memory key) internal pure returns (string memory, string memory) {
        bytes memory keyBytes = bytes(key);
        uint256 separatorIndex = keyBytes.length;
       for (uint256 i = 0; i < keyBytes.length; i++) {
            if (keyBytes[i] == "-") {
                separatorIndex = i;
                break;
            }
        }
        require(separatorIndex != keyBytes.length, "Invalid key format");
        bytes memory idSource = new bytes(separatorIndex);
        bytes memory id = new bytes(keyBytes.length - separatorIndex - 1);
    
        for (uint256 i = 0; i < separatorIndex; i++) {
            idSource[i] = keyBytes[i];
        }
        for (uint256 i = separatorIndex + 1; i < keyBytes.length; i++) {
            id[i - separatorIndex - 1] = keyBytes[i];
        }
        require(separatorIndex > 0 && separatorIndex < keyBytes.length - 1, "Invalid key format");
        return (string(idSource), string(id));
    }
}
