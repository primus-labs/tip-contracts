// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {PrimusTip} from "../src/PrimusTip.sol";
import {PrimusRedEnvelope} from "../src/PrimusRedEnvelope.sol";
import {QueryOwners, IOwnership} from "../script/QueryOwners.s.sol";
import {TransferOwners} from "../script/TransferOwners.s.sol";

contract OwnerScriptsTest is Test {
    bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    uint256 constant BUSINESS_KEY = 0x123;
    uint256 constant ADMIN_KEY = 0x456;
    address constant NEW_OWNER = address(0x789);
    address constant FEE_RECIPIENT = address(0xabc);
    address[4] targets;
    TransferOwners transferScript;

    function setUp() public {
        bytes memory init = abi.encodeWithSelector(
            PrimusTip.initialize.selector, vm.addr(BUSINESS_KEY), address(0xdef), FEE_RECIPIENT, uint256(0)
        );
        targets[0] = address(new TransparentUpgradeableProxy(address(new PrimusTip()), vm.addr(ADMIN_KEY), init));
        targets[2] =
            address(new TransparentUpgradeableProxy(address(new PrimusRedEnvelope()), vm.addr(ADMIN_KEY), init));
        targets[1] = address(uint160(uint256(vm.load(targets[0], ADMIN_SLOT))));
        targets[3] = address(uint160(uint256(vm.load(targets[2], ADMIN_SLOT))));
        vm.setEnv("TIP_PROXY_ADDRESS", vm.toString(targets[0]));
        vm.setEnv("RED_ENVELOPE_PROXY_ADDRESS", vm.toString(targets[2]));
        vm.setEnv("NEW_OWNER", vm.toString(NEW_OWNER));
        vm.setEnv("PRIVATE_KEY", vm.toString(BUSINESS_KEY));
        vm.setEnv("PROXY_ADMIN_PRIVATE_KEY", vm.toString(ADMIN_KEY));
        transferScript = new TransferOwners();
    }

    // Environment variables are process-wide: keep scenarios in one test so
    // Foundry's parallel test runner cannot race on the script configuration.
    function testOwnershipScriptScenarios() public {
        _queryDoesNotChangeOwners();
        _transferWithSeparateKeysAndRerun();
        setUp();
        _resumePartialTransfer();
        setUp();
        _wrongAdminKeyRejectedBeforeAnyTransfer();
        setUp();
        _zeroOwnerRejected();
    }

    function _queryDoesNotChangeOwners() internal {
        new QueryOwners().run();
        _assertOriginalOwners();
    }

    function _transferWithSeparateKeysAndRerun() internal {
        transferScript.run();
        for (uint256 i; i < targets.length; i++) {
            assertEq(IOwnership(targets[i]).owner(), NEW_OWNER);
        }
        assertEq(PrimusTip(targets[0]).feeRecipient(), FEE_RECIPIENT);
        assertEq(PrimusRedEnvelope(targets[2]).feeRecipient(), FEE_RECIPIENT);
        transferScript.run();
    }

    function _resumePartialTransfer() internal {
        vm.prank(vm.addr(BUSINESS_KEY));
        IOwnership(targets[0]).transferOwnership(NEW_OWNER);
        transferScript.run();
        for (uint256 i; i < targets.length; i++) {
            assertEq(IOwnership(targets[i]).owner(), NEW_OWNER);
        }
    }

    function _wrongAdminKeyRejectedBeforeAnyTransfer() internal {
        vm.setEnv("PROXY_ADMIN_PRIVATE_KEY", vm.toString(BUSINESS_KEY));
        vm.expectRevert("Signer is not current owner");
        transferScript.run();
        _assertOriginalOwners();
    }

    function _zeroOwnerRejected() internal {
        vm.setEnv("NEW_OWNER", vm.toString(address(0)));
        vm.expectRevert("NEW_OWNER must not be zero");
        transferScript.run();
        _assertOriginalOwners();
    }

    function _assertOriginalOwners() internal view {
        for (uint256 i; i < targets.length; i++) {
            assertEq(IOwnership(targets[i]).owner(), vm.addr(i % 2 == 0 ? BUSINESS_KEY : ADMIN_KEY));
        }
    }
}
