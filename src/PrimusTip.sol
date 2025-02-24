// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {TipRecipientReq, TipRecipient} from "./types/Common.sol";

/**
 * @dev The Primus Tip contract is used to manage users’ tip funds.
 *      Tippers can lock funds in contracts, and recipients can claim the tip funds after verifying their identities.
 */
contract PrimusTip is OwnableUpgradeable {
    /**
     * @dev Initialize function to set the owner of the contract.
     *      This function is called during the contract deployment.
     * @param owner The contract owner.
     */
    function initialize(address owner) public initializer {
        __Ownable_init(owner);
    }

    /**
     * @dev Tipper tip the token to the recipient.
     *      Tipper can tip erc20, NFT and native token.
     *      Tipper tip the native token when the token.tokenName equals to native.
     * @param token The tip token.
     * @param recipient The recipient informations.
     */
    function tip(TipToken calldata token, TipRecipientReq calldata recipient) external payable {}

    /**
     * @dev Tipper tip the token to the batch recipients.
     *      Tipper can tip erc20, NFT and native token.
     *      Tipper tip the native token when the token.tokenName equals to native.
     * @param token The tip token.
     * @param recipient The recipients informations.
     */
    function tipBatch(TipToken calldata token, TipRecipientReq[] calldata recipients) external payable {}

    /**
     * @dev Recipient claims the tip tokens.
     */
    function claimById(TipRecipient calldata recipient, ) external payable {}
}
