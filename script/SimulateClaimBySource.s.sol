// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {PrimusTip} from "../src/PrimusTip.sol";
import {TipRecipient, TipRecord} from "../src/types/Common.sol";
import {ClaimBySourceAttestation} from "../test/fixtures/ClaimBySourceAttestation.sol";
import {Attestation} from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";

/// @notice Fork-only replay of the supplied signed attestation, with real verification.
/// Run without --broadcast. The second call uses the fixed implementation only in the local fork.
contract SimulateClaimBySource is Script {
    /// @notice Simulate the original parameters against the live implementation,
    /// without changing implementation storage, recipient code, or verification.
    function verifyLive() external {
        require(block.chainid == 8453, "Use a Base mainnet fork");
        PrimusTip tip = PrimusTip(0xa2e0700a269Be3158c81E4739518b324d4398588);
        Attestation memory att = ClaimBySourceAttestation.load();
        TipRecipient memory account = TipRecipient("x", "daegu3071");
        TipRecord[] memory records = tip.getTipRecords(account);
        uint256 amount;
        for (uint256 i; i < records.length; ++i) {
            require(records[i].tipToken.tokenType == 1, "Expected native tips");
            amount += records[i].amount;
        }
        console.log("Fork block", block.number);
        console.log("Pending records", records.length);
        console.log("Native amount (wei)", amount);
        uint256 beforeBalance = att.recipient.balance;
        uint256 requiredFee = tip.claimFee() * records.length;
        // Same caller, idSource, full signed proof and msg.value as the report.
        vm.prank(att.recipient);
        tip.claimBySource{value: 0.0001 ether}("x", att);
        require(tip.getTipRecords(account).length == 0, "Records not cleared");
        require(att.recipient.balance == beforeBalance + amount - requiredFee, "Unexpected balance");
        console.log("Live implementation claim succeeded with original parameters");
    }

    function run() public {
        require(block.chainid == 8453, "Use a Base mainnet fork");
        PrimusTip tip = PrimusTip(0xa2e0700a269Be3158c81E4739518b324d4398588);
        address claimant = 0x6311c8a4F9CCa5a8FDFbc7a95FC565225d253c21;
        TipRecipient memory account = TipRecipient("x", "daegu3071");
        TipRecord[] memory records = tip.getTipRecords(account);
        uint256 amount;
        for (uint256 i; i < records.length; ++i) {
            require(records[i].tipToken.tokenType == 1, "Expected native tips");
            amount += records[i].amount;
        }
        require(records.length > 0, "No pending tips at this block");

        Attestation memory att = ClaimBySourceAttestation.load();
        require(att.recipient == claimant, "Unexpected proof recipient");

        uint256 fee = 0.0001 ether;
        console.log("Fork block", block.number);
        console.log("Pending records", records.length);
        console.log("Native amount (wei)", amount);
        console.log("Required fee (wei)", tip.claimFee() * records.length);
        console.log("Recipient code length", claimant.code.length);
        console.logBytes(claimant.code);
        uint256 beforeBalance = claimant.balance;
        require(beforeBalance >= fee, "Claimant cannot fund fee");
        vm.prank(claimant);
        (bool success, bytes memory reason) =
            address(tip).call{value: fee}(abi.encodeCall(PrimusTip.claimBySource, ("x", att)));
        require(!success, "Expected original recipient to revert; inspect changed state");
        console.log("Original recipient reverted; revert bytes", reason.length);
        require(claimant.balance == beforeBalance, "Failed claim changed balance");
        require(tip.getTipRecords(account).length == records.length, "Failed claim changed records");

        // Simulate an implementation upgrade ONLY IN THE LOCAL FORK.
        // Preserve proxy storage, real verifier and the recipient's delegation.
        bytes32 recipientCodeHash = claimant.codehash;
        PrimusTip fixedImplementation = new PrimusTip();
        bytes32 implementationSlot = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
        vm.store(address(tip), implementationSlot, bytes32(uint256(uint160(address(fixedImplementation)))));
        vm.prank(claimant);
        tip.claimBySource{value: fee}("x", att);
        require(tip.getTipRecords(account).length == 0, "Records not cleared");
        require(claimant.balance == beforeBalance + amount - fee, "Unexpected claimant balance");
        require(claimant.codehash == recipientCodeHash, "Recipient code changed");
        console.log("Fixed implementation succeeded with REAL verification and unchanged recipient code");
    }
}
