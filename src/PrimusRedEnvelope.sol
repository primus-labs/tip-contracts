// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IPrimusZKTLS, Attestation} from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";
import {TipToken, RESendParam, RERecord} from "./types/Common.sol";
import "./utils/StringUtils.sol";
import "./utils/JsonParser.sol";

contract PrimusRedEnvelope is OwnableUpgradeable {
    using StringUtils for string;
    using JsonParser for string;

    event RESendEvent(bytes32 indexed id, address reSender, uint32 tokenType, address tokenAddress, uint256 amount, uint32 reType, uint32 number, uint64 timestamp);
    event REClaimEvent(bytes32 indexed id, address recipient, uint256 amount, uint64 timestamp);


    // IPrimusZKTLS contract
    IPrimusZKTLS public primusZKTLS;
    // claim fee
    uint256 public claimFee;
    // fee recipient address
    address public feeRecipient;
    // withdraw delay
    uint256 public withdrawDelay;

    mapping(bytes32 => RERecord) public reRecords;


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

    /**
     * @dev Red envelope sender send the token to users.
     *      Sender can send erc20, and native token.
     * @param token The send token of the red envelope.
     * @param sendParam The red envelope informations.
     */
    function reSend(TipToken memory token, RESendParam memory sendParam) external payable {

    }

    /**
     * @dev Users claim the red envelope.
     * @param reId The red envelope id.
     * @param att Attestation to prove that the red envelope conditions are met.
     */
    function reClaim(bytes32 reId, Attestation calldata att) external payable {

    }

    function senderWithdraw(bytes32 reId) external {

    }

    /**
     * @dev Check if Attestation meets the red envelope conditions.
     *      If the check fails, an exception must be thrown.
     * @param att Attestation to prove that the red envelope conditions are met.
     * @return User id in Attestation. User id cannot be an empty string.
     */
    function reCheckClaim(Attestation calldata att) public returns (string memory) {

    }

    function getREInfo(bytes32 reId) external view returns (RERecord memory) {
        return reRecords[reId];
    }
}