// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {PrimusTip} from "../src/PrimusTip.sol";
import {UpgradeScript} from "../script/UpgradeScript.s.sol";

contract UpgradeScriptTest is Test {
    bytes32 constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    uint256 constant ADMIN_KEY = 0x456;

    // Keep environment-driven scenarios sequential within this suite.
    function testUpgradeFromProxyAddress() public {
        PrimusTip original = new PrimusTip();
        address proxy = address(
            new TransparentUpgradeableProxy(
                address(original),
                vm.addr(ADMIN_KEY),
                abi.encodeWithSelector(
                    PrimusTip.initialize.selector, address(this), address(0xdef), address(0xabc), uint256(123)
                )
            )
        );
        UpgradeScript script = new UpgradeScript();
        vm.setEnv("TIP_PROXY_ADDRESS", vm.toString(proxy));
        vm.setEnv("PRIVATE_KEY", vm.toString(uint256(0x123)));
        uint64 nonceBefore = vm.getNonce(vm.addr(0x123));
        vm.expectRevert("PRIVATE_KEY is not ProxyAdmin owner");
        script.run();
        assertEq(vm.getNonce(vm.addr(0x123)), nonceBefore);
        assertEq(address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT)))), address(original));

        vm.setEnv("PRIVATE_KEY", vm.toString(ADMIN_KEY));
        script.run();
        address upgraded = address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT))));
        assertNotEq(upgraded, address(original));
        assertEq(upgraded.codehash, address(original).codehash);
        assertEq(PrimusTip(proxy).owner(), address(this));
        assertEq(PrimusTip(proxy).claimFee(), 123);
        assertEq(PrimusTip(proxy).feeRecipient(), address(0xabc));
        assertEq(address(PrimusTip(proxy).primusZKTLS()), address(0xdef));

        vm.setEnv("TIP_PROXY_ADDRESS", vm.toString(address(0)));
        vm.expectRevert("TIP_PROXY_ADDRESS has no code");
        script.run();
        vm.setEnv("TIP_PROXY_ADDRESS", vm.toString(address(original)));
        vm.expectRevert("ProxyAdmin has no code");
        script.run();
    }
}
