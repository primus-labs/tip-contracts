// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";
import {QueryOwners, IOwnership} from "./QueryOwners.s.sol";

contract TransferOwners is QueryOwners {
    function run() public override {
        address[4] memory targets = _targets();
        address newOwner = vm.envAddress("NEW_OWNER");
        require(newOwner != address(0), "NEW_OWNER must not be zero");
        uint256 businessKey = vm.envUint("PRIVATE_KEY");
        uint256 adminKey = vm.envOr("PROXY_ADMIN_PRIVATE_KEY", businessKey);
        address businessSigner = vm.addr(businessKey);
        address adminSigner = vm.addr(adminKey);

        console.log("Chain ID:", block.chainid);
        console.log("New owner:", newOwner);
        _printOwners(targets);

        // Validate every target before recording any transaction.
        for (uint256 i; i < targets.length; i++) {
            address currentOwner = IOwnership(targets[i]).owner();
            address signer = i % 2 == 0 ? businessSigner : adminSigner;
            require(currentOwner == newOwner || currentOwner == signer, "Signer is not current owner");
        }

        for (uint256 i; i < targets.length; i++) {
            // Allows rerunning after a partially completed broadcast.
            if (IOwnership(targets[i]).owner() == newOwner) {
                console.log("Already transferred, skipping:", targets[i]);
                continue;
            }
            vm.startBroadcast(i % 2 == 0 ? businessKey : adminKey);
            IOwnership(targets[i]).transferOwnership(newOwner);
            vm.stopBroadcast();
            require(IOwnership(targets[i]).owner() == newOwner, "Ownership transfer failed");
        }

        console.log("Owners after transfer (simulation):");
        _printOwners(targets);
    }
}
