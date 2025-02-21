// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {TipRecipient} from "./types/Common.sol";

/**
 * @dev The Primus Tip contract is used to manage users’ tip funds.
 *      Tippers can lock money in contracts, and recipients can claim the tip funds after verifying their identities.
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
     *      Tipper tip the native token when the token param equals to native.
     * @param token The tip token.
     * @param recipient The recipient informations include the identifier of the account and the platform.
     */
    function tip(string calldata token, TipRecipient calldata recipient) external payable {}
}
