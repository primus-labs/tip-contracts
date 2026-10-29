// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PrimusTipTest} from "./PrimusTip.t.sol";
import {TestUtils} from "./TestUtils.sol";
import {TipToken, TipRecipientInfo, TipRecipient, TipWithdrawInfo} from "../src/types/Common.sol";
import {Attestation} from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";

contract NativePaymentReceiver {
    uint256 public received;
    bool public reject;
    address public target;
    bytes public callback;
    bool public callbackSucceeded;
    bytes public callbackResult;

    function configure(bool reject_, address target_, bytes memory callback_) external {
        reject = reject_;
        target = target_;
        callback = callback_;
    }

    receive() external payable {
        require(!reject, "Receiver rejected ETH");
        received += msg.value; // Storage write requires more than the transfer stipend.
        if (target != address(0)) {
            (callbackSucceeded, callbackResult) = target.call(callback);
        }
    }
}

contract PrimusTipNativePaymentsTest is PrimusTipTest {
    function _deposit(address sender) internal {
        vm.deal(sender, 3 ether);
        vm.prank(sender);
        primusTip.tip{value: 1 ether}(
            TipToken({tokenType: 1, tokenAddress: address(0)}),
            TipRecipientInfo({idSource: "x", id: "wenjun_yuan1", amount: 1 ether, nftIds: new uint256[](0)})
        );
    }

    function _proof(address recipient) internal pure returns (Attestation memory att) {
        (att,,) = TestUtils._createXAttestation();
        att.recipient = recipient;
    }

    function test_NativeClaimAndRefundToSmartAccount() public {
        NativePaymentReceiver receiver = new NativePaymentReceiver();
        _deposit(tipper);
        vm.prank(owner);
        primusTip.setClaimFee(0.1 ether);
        vm.deal(address(receiver), 0.2 ether);
        vm.prank(address(receiver));
        primusTip.claimBySource{value: 0.2 ether}("x", _proof(address(receiver)));
        assertEq(receiver.received(), 1.1 ether);
        assertEq(address(receiver).balance, 1.1 ether);
        assertEq(feeRecipient.balance, 0.1 ether);
        assertEq(primusTip.getTipRecords(TipRecipient({idSource: "x", id: "wenjun_yuan1"})).length, 0);
    }

    function test_NativeMultiSourceClaimAndRefundToSmartAccount() public {
        NativePaymentReceiver receiver = new NativePaymentReceiver();
        _deposit(tipper);
        string[] memory sources = new string[](1);
        sources[0] = "x";
        Attestation[] memory proofs = new Attestation[](1);
        proofs[0] = _proof(address(receiver));
        vm.deal(address(receiver), 0.1 ether);
        vm.prank(address(receiver));
        primusTip.claimByMultiSource{value: 0.1 ether}(sources, proofs);
        assertEq(receiver.received(), 1.1 ether);
        assertEq(primusTip.getTipRecords(TipRecipient({idSource: "x", id: "wenjun_yuan1"})).length, 0);
    }

    function test_NativeRejectedClaimRestoresRecordsAndBalance() public {
        NativePaymentReceiver receiver = new NativePaymentReceiver();
        receiver.configure(true, address(0), "");
        _deposit(tipper);
        vm.expectRevert(bytes("Native transfer failed"));
        primusTip.claimBySource("x", _proof(address(receiver)));
        assertEq(address(primusTip).balance, 1 ether);
        assertEq(address(receiver).balance, 0);
        assertEq(primusTip.getTipRecords(TipRecipient({idSource: "x", id: "wenjun_yuan1"})).length, 1);
    }

    function test_NativeRejectedRefundRollsBackSuccessfulPayout() public {
        NativePaymentReceiver sender = new NativePaymentReceiver();
        sender.configure(true, address(0), "");
        _deposit(tipper);
        vm.deal(address(sender), 0.1 ether);
        uint256 beforeBalance = recipientAddr.balance;
        vm.prank(address(sender));
        vm.expectRevert(bytes("Native transfer failed"));
        primusTip.claimBySource{value: 0.1 ether}("x", _proof(recipientAddr));
        assertEq(recipientAddr.balance, beforeBalance);
        assertEq(address(sender).balance, 0.1 ether);
        assertEq(address(primusTip).balance, 1 ether);
        assertEq(primusTip.getTipRecords(TipRecipient({idSource: "x", id: "wenjun_yuan1"})).length, 1);
    }

    function test_NativeReceiverCannotReenterAnotherFundsEntry() public {
        NativePaymentReceiver receiver = new NativePaymentReceiver();
        _deposit(tipper);
        TipWithdrawInfo[] memory withdrawals = new TipWithdrawInfo[](0);
        receiver.configure(
            false, address(primusTip), abi.encodeWithSelector(primusTip.tipperWithdraw.selector, withdrawals)
        );
        primusTip.claimBySource("x", _proof(address(receiver)));
        assertFalse(receiver.callbackSucceeded());
        assertEq(receiver.callbackResult(), abi.encodeWithSignature("ReentrancyGuardReentrantCall()"));
        assertEq(receiver.received(), 1 ether);
        assertEq(address(primusTip).balance, 0);
    }

    function test_NativeTipRefundsToSmartAccount() public {
        NativePaymentReceiver sender = new NativePaymentReceiver();
        vm.deal(address(sender), 3 ether);
        vm.prank(address(sender));
        primusTip.tip{value: 2 ether}(
            TipToken({tokenType: 1, tokenAddress: address(0)}),
            TipRecipientInfo({idSource: "x", id: "wenjun_yuan1", amount: 1 ether, nftIds: new uint256[](0)})
        );
        assertEq(sender.received(), 1 ether);
        TipRecipientInfo[] memory recipients = new TipRecipientInfo[](1);
        recipients[0] = TipRecipientInfo({idSource: "x", id: "wenjun_yuan1", amount: 1 ether, nftIds: new uint256[](0)});
        vm.prank(address(sender));
        primusTip.tipBatch{value: 2 ether}(TipToken({tokenType: 1, tokenAddress: address(0)}), recipients);
        assertEq(sender.received(), 2 ether);
        assertEq(address(primusTip).balance, 2 ether);
        assertEq(primusTip.getTipRecords(TipRecipient({idSource: "x", id: "wenjun_yuan1"})).length, 2);
    }

    function test_NativeWithdrawalToSmartAccount() public {
        NativePaymentReceiver sender = new NativePaymentReceiver();
        _deposit(address(sender));
        uint64 timestamp = primusTip.getTipRecords(TipRecipient({idSource: "x", id: "wenjun_yuan1"}))[0].timestamp;
        vm.warp(block.timestamp + 30 days);
        TipWithdrawInfo[] memory withdrawals = new TipWithdrawInfo[](1);
        withdrawals[0] = TipWithdrawInfo({idSource: "x", id: "wenjun_yuan1", tipTimestamp: timestamp});
        vm.prank(address(sender));
        primusTip.tipperWithdraw(withdrawals);
        assertEq(sender.received(), 1 ether);
        assertEq(address(primusTip).balance, 0);
        assertEq(primusTip.getTipRecords(TipRecipient({idSource: "x", id: "wenjun_yuan1"})).length, 0);
    }
}
