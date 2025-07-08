// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IPrimusZKTLS, Attestation} from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";
import {TipToken, RESendParam, RERecord, ERC20_TYPE, NATIVE_TYPE} from "./types/Common.sol";
import "./utils/StringUtils.sol";
import "./utils/JsonParser.sol";

contract PrimusRedEnvelope is OwnableUpgradeable {
    using StringUtils for string;
    using JsonParser for string;

    event RESendEvent(bytes32 indexed id, address reSender, uint32 tokenType, address tokenAddress, uint256 amount, uint32 reType, uint32 number, uint64 timestamp, bytes checkParams);
    event REClaimEvent(bytes32 indexed id, address recipient, string userId, uint256 claimAmount, uint32 reIndex, uint64 timestamp, address tokenAddress);
    event RESWithdrawEvent(bytes32 indexed id, address reSender, uint256 amount, uint32 remainingNumber, uint64 timestamp);

    uint256 public idCounter;
    // IPrimusZKTLS contract
    IPrimusZKTLS public primusZKTLS;
    // claim fee
    uint256 public claimFee;
    // fee recipient address
    address public feeRecipient;
    // withdraw delay
    uint256 public withdrawDelay;
    mapping(bytes32 => RERecord) public reRecords;
    // Indicates whether the user id have claimed the red envelope. The user id is source name + id, such as "xusername".
    mapping(bytes32 => mapping(string => bool)) reClaimed;

    uint32 constant RE_RANDOM = 0;
    uint32 constant RE_AVERAGE = 1;

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
     * @dev Red envelope sender send the token to users.
     *      Sender can send erc20, and native token.
     * @param token The send token of the red envelope.
     * @param sendParam The red envelope informations.
     */
    function reSend(TipToken memory token, RESendParam calldata sendParam) external payable {
        require(token.tokenType == ERC20_TYPE || token.tokenType == NATIVE_TYPE, "error token type");
        if (token.tokenType == ERC20_TYPE) {
            require(token.tokenAddress != address(0), "error token addr");
        } else if (token.tokenType == NATIVE_TYPE) {
            token.tokenAddress = address(0);
        }
        require(sendParam.reType == RE_RANDOM || sendParam.reType == RE_AVERAGE, "error re type");
        require(sendParam.number > 0, "error re number");
        require(sendParam.amount >= sendParam.number, "reamount too low");
        _transferFromUser(msg.sender, token, sendParam.amount);
        idCounter++;
        bytes32 reId = _generateReId(idCounter);
        RERecord memory reRecord = RERecord({
            id: reId,
            tokenType: token.tokenType,
            reType: sendParam.reType,
            number: sendParam.number,
            remainingNumber: sendParam.number,
            timestamp: (uint64)(block.timestamp),
            tokenAddress: token.tokenAddress,
            reSender: msg.sender,
            checkContract: sendParam.checkContract,
            amount: sendParam.amount,
            remainingAmount: sendParam.amount,
            checkParams: sendParam.checkParams
        });
        reRecords[reRecord.id] = reRecord;
        emit RESendEvent(reRecord.id, reRecord.reSender, reRecord.tokenType, reRecord.tokenAddress, reRecord.amount, reRecord.reType, reRecord.number, reRecord.timestamp, reRecord.checkParams);
    }

    /**
     * @dev Users claim the red envelope.
     * @param reId The red envelope id.
     * @param att Attestation to prove that the red envelope conditions are met.
     */
    function reClaim(bytes32 reId, Attestation calldata att) external payable {
        RERecord storage reRecord = reRecords[reId];
        require(reRecord.id != bytes32(0), "no reId");
        require(reRecord.remainingNumber > 0, "All claimed");
        (string memory userId, address userAddr) = reCheckClaim(att, reRecord.checkParams);
        require(!userId.equals(""), "userId empty");
        require(!reClaimed[reId][userId], "Already claimed");
        if (claimFee > 0) {
            // payable(feeRecipient).transfer(fee);
            (bool sent,) = feeRecipient.call{value: claimFee}("");
            require(sent, "Failed to send fee");
        }
        uint256 amount = _getReAmount(reId);
        reRecord.remainingAmount -= amount;
        reRecord.remainingNumber -= 1;
        reClaimed[reId][userId] = true;
        _transferToUser(reRecord.tokenType, reRecord.tokenAddress, userAddr, amount);
        emit REClaimEvent(reRecord.id, userAddr, userId, amount, reRecord.number - reRecord.remainingNumber, (uint64)(block.timestamp), reRecord.tokenAddress);
    }

    function reSenderWithdraw(bytes32 reId) external {
        RERecord storage reRecord = reRecords[reId];
        require(reRecord.id != bytes32(0), "no reId");
        require(reRecord.remainingAmount > 0, "no fund");
        require(reRecord.reSender == msg.sender, "not owner");
        require(block.timestamp >= reRecord.timestamp + withdrawDelay, "not expired");
        uint256 amount = reRecord.remainingAmount;
        uint32 remainingNumber = reRecord.remainingNumber;
        reRecord.remainingAmount = 0;
        reRecord.remainingNumber = 0;
        _transferToUser(reRecord.tokenType, reRecord.tokenAddress, msg.sender, amount);
        emit RESWithdrawEvent(reRecord.id, msg.sender, amount, remainingNumber, (uint64)(block.timestamp));
    }

    /**
     * @dev Check if Attestation meets the red envelope conditions.
     *      If the check fails, an exception must be thrown.
     * @param att Attestation to prove that the red envelope conditions are met.
     * @return User id and address in Attestation. User id cannot be an empty string.
     */
    function reCheckClaim(Attestation calldata att, bytes memory checkParams) public view returns (string memory, address) {
        require(att.recipient != address(0), "to addr zero");
        primusZKTLS.verifyAttestation(att);
        (uint32 checkType, string memory params) = abi.decode(checkParams, (uint32, string));
        require(checkType == 0 || checkType == 1, "error checkType");
        if (checkType == 0) {
            return checkXFollowing(att, params);
        } else {
            return checkAccount(att, params);
        }
    }

    function checkXFollowing(Attestation calldata att, string memory params) public pure returns (string memory, address) {
        require(att.reponseResolve.length == 2, "response length error");
        string memory baseUrl = att.request.url.extractStr("?");
        require(baseUrl.startsWith("https://x.com/i/api/graphql"), "att url error");
        require(baseUrl.suffixWith("UserByScreenName"), "att suffix url error");
        require(att.reponseResolve[0].parsePath.equals("$.data.user.result.relationship_perspectives.following"), "json path error");
        require(att.reponseResolve[1].parsePath.equals("$.data.user.result.core.screen_name"), "json path error");
        require(!att.reponseResolve[0].keyName.equals(att.reponseResolve[1].keyName), "following key error");

        string[] memory keys = new string[](5);
        keys[0] = "requests[2].url";
        keys[1] = "reponseResolves[1][1].parsePath";
        keys[2] = "requests[1].url";
        keys[3] = "reponseResolves[1][0].parsePath";
        keys[4] = "reponseResolves[1][0].keyName";
        string[] memory values = att.additionParams.extractArrayValue(keys);
        string memory urlCheck = values[0];
        require(urlCheck.equals(""), "too more url");
        string memory parseCheck = values[1];
        require(parseCheck.equals(""), "too more reponseResolves");

        string memory url1 = values[2];
        string memory reponseResolve1 = values[3];
        string memory keyName1 = values[4];
        require(url1.startsWith("https://api.x.com/1.1/account/settings.json"), "att url error");
        require(reponseResolve1.equals("$.screen_name"), "json path error");
        require(!keyName1.equals(att.reponseResolve[0].keyName) && !keyName1.equals(att.reponseResolve[1].keyName), "username key error");

        string memory following = att.data.extractValue(att.reponseResolve[0].keyName);
        require(following.equals("true"), "following error");
        string memory followingName = att.data.extractValue(att.reponseResolve[1].keyName);
        require(followingName.equals(params), "following Name error");
        string memory userName = att.data.extractValue(keyName1);
        require(!userName.equals(""), "username empty");
        return (userName.addPrefix("x"), att.recipient);
    }

    function checkAccount(Attestation calldata att, string memory params) public pure returns (string memory, address) {
        require(params.equals("tiktok") || params.equals("x") || params.equals("google account") || params.equals("xiaohongshu"), "error source");
        string memory urlCheck = att.additionParams.extractValue("requests[1].url");
        require(urlCheck.equals(""), "too more url");
        require(att.reponseResolve.length == 1, "account response length error");
        string memory userName;
        if (params.equals("tiktok")) {
            require(att.request.url.startsWith("https://www.tiktok.com/passport/web/account/info/"), "tiktok att url error");
            require(att.reponseResolve[0].parsePath.equals("$.data.username"), "tiktok json path error");
            userName = att.data.extractValue(att.reponseResolve[0].keyName);
        } else if (params.equals("x")) {
            require(att.request.url.startsWith("https://api.x.com/1.1/account/settings.json"), "x att url error");
            require(att.reponseResolve[0].parsePath.equals("$.screen_name"), "x json path error");
            userName = att.data.extractValue(att.reponseResolve[0].keyName);
        } else if (params.equals("google account")) {
            require(att.request.url.startsWith("https://developers.google.com/_d/profile/user"), "google att url error");
            require(att.reponseResolve[0].parsePath.equals("$[2]"), "google json path error");
            userName = att.data.extractValue(att.reponseResolve[0].keyName);
        } else {
            require(att.request.url.startsWith("https://edith.xiaohongshu.com/api/sns/web/v2/user/me"), "xiaohongshu att url error");
            require(att.reponseResolve[0].parsePath.equals("$.data.red_id"), "xiaohongshu json path error");
            userName = att.data.extractValue(att.reponseResolve[0].keyName);
        }
        require(!userName.equals(""), "username empty");
        return (userName.addPrefix(params), att.recipient);
    }

    function getREInfo(bytes32 reId) external view returns (RERecord memory) {
        return reRecords[reId];
    }

    function getClaimed(bytes32 reId, string memory userid) external view returns (bool) {
        return reClaimed[reId][userid];
    }

    function getPrev() external view returns (uint256, uint256) {
        return (block.prevrandao, block.number);
    }

    // ========== external onlyOwner functions ==========
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
     *  @param claimFee_ The claim fee
     */
    function setClaimFee(uint256 claimFee_) external onlyOwner {
        claimFee = claimFee_;
    }

    // ========== internal functions ==========
    /**
     * @dev Transfer the token from the user to the contract.
     * @param from The token sender.
     * @param token The send token.
     * @param amount The token amount.
    */
    function _transferFromUser(address from, TipToken memory token, uint256 amount) internal {
        if (token.tokenType == ERC20_TYPE) {
            IERC20 reToken = IERC20(token.tokenAddress);
            bool ret = reToken.transferFrom(from, address(this), amount);
            require(ret, "transfer fail");
        } else if (token.tokenType == NATIVE_TYPE) {
            require(msg.value == amount, "wrong amount");
        }
    }

    function _transferToUser(uint32 tokenType, address tokenAddress, address userAddr, uint256 amount) internal {
        if (tokenType == ERC20_TYPE) {
            IERC20 sendToken = IERC20(tokenAddress);
            require(sendToken.transfer(userAddr, amount), "Transfer failed");
        } else if (tokenType == NATIVE_TYPE) {
            payable(userAddr).transfer(amount);
        }
    }

    function _getReAmount(bytes32 reId) internal view returns (uint256) {
        RERecord storage reRecord = reRecords[reId];
        if (reRecord.remainingNumber == 1) {
            return reRecord.remainingAmount;
        }
        uint256 amount;
        if (reRecord.reType == RE_AVERAGE) {
            amount = reRecord.amount / reRecord.number;
            return amount;
        }
        uint256 minAmount = 1;
        uint256 avg = reRecord.remainingAmount / reRecord.remainingNumber;
        uint256 factor = 3;
        uint256 maxAmount = avg * factor;
        uint256 minRemaining = (reRecord.remainingNumber - 1) * minAmount;
        if (reRecord.remainingAmount <= minRemaining) {
            return 0;
        }
        uint256 maxSafe = reRecord.remainingAmount - minRemaining;
        uint256 upperBound = maxAmount < maxSafe ? maxAmount : maxSafe;
        if (upperBound <= minAmount) {
            return 0;
        }
        uint256 seed = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, block.prevrandao, blockhash(block.number - 1), reId)));
        amount = seed % (upperBound - minAmount + 1) + minAmount;
        return amount;
    }

    function _generateReId(uint256 idCnt) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(block.chainid, idCnt));
    }

}