// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPrimusZKTLS, Attestation } from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";
import {TipToken, TipRecipientReq, TipRecipient, TipRecord} from "./types/Common.sol";
import "./utils/StringUtils.sol";

/**
 * @dev The Primus Tip contract is used to manage users’ tip funds.
 *      Tippers can lock funds in contracts, and recipients can claim the tip funds after verifying their identities.
 */
contract PrimusTip is OwnableUpgradeable {
    using StringUtils for string;

    mapping(string => mapping(string => TipRecord)) private attestationsOfAddress;

    // IPrimusZKTLS contract
    IPrimusZKTLS public primusZKTLS;
    // claim fee
    uint256 public claimFee;

    /**
     * @dev Initialize function to set the owner of the contract.
     *      This function is called during the contract deployment.
     * @param owner The contract owner.
     */
    function initialize(address owner, IPrimusZKTLS primusZKTLS_) public initializer {
        __Ownable_init(owner);
        primusZKTLS = primusZKTLS_;
    }

    /**
     * @dev Tipper tip the token to the recipient.
     *      Tipper can tip erc20, NFT and native token.
     *      Tipper tip the native token when the token.tokenName equals to native.
     * @param token The tip token.
     * @param recipient The recipient informations.
     */
    function tip(TipToken calldata token, TipRecipientReq calldata recipient) external payable {
        require(token.tokenType.equals("erc20") || token.tokenType.equals("native"), "not support token type");
        if (token.tokenType.equals("erc20")) {
            IERC20 tipToken = IERC20(token.tokenAddress);
            bool ret = tipToken.transferFrom(msg.sender, address(this), recipient.amount);
            require(ret, "transfer token fail");
            // TODO
        }
    }

    /**
     * @dev Tipper tip the token to the batch recipients.
     *      Tipper can tip erc20, NFT and native token.
     *      Tipper tip the native token when the token.tokenName equals to native.
     * @param token The tip token.
     * @param recipients The recipients informations.
     */
    function tipBatch(TipToken calldata token, TipRecipientReq[] calldata recipients) external payable {}

    /**
     * @dev Recipient claims the tip tokens by id source and tip tokens.
     */
    function claimBySourceAndToken(string calldata idSource, Attestation calldata att, TipToken[] calldata token, address to) external payable {}

    /**
     * @dev Recipient claims the tip tokens by the id source.
     */
    function claimBySource(string calldata idSource, Attestation calldata att, address to) external payable {}

    /**
     * @dev Recipient claims the tip tokens by id sources.
     */
    function claimByMultiSource(string[] calldata idSources, Attestation[] calldata att, address to) external payable {}

    /**
     * @dev The tipper withdraws tokens that have not been claimed within the specified time period.
     */
    function tipperWithdraw() external {}

    /**
     * @dev Get the tip tokens by id and id source of recipient.
     */
    function getTipTokens(TipRecipient calldata tipRecipient) external view returns (TipToken[] memory token) {}


    /**
     * @dev Add the id attestation source.
     */
    function addIdSource() external onlyOwner {}

    /**
     *  @dev set IPrimusZKTLS contract instance
     *  @param primusZKTLS_ The address of the IPrimusZKTLS contract
     */
    function setPrimusZKTLS(IPrimusZKTLS primusZKTLS_) public onlyOwner {
        primusZKTLS = primusZKTLS_;
    }

    /**
     *  @dev set claim fee
     *  @param claimFee_ The submission fee
     */
    function setClaimFee(uint256 claimFee_) public onlyOwner {
        claimFee = claimFee_;
    }
}
