// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {PrimusTip} from "../src/PrimusTip.sol";
import {UpgradeScript} from "../script/UpgradeScript.s.sol";

// Inject configuration per test instance instead of mutating process-wide env vars.
contract UpgradeScriptHarness is UpgradeScript {
    address internal configuredProxy;
    uint256 internal configuredKey;

    function configure(address proxy, uint256 key) external {
        configuredProxy = proxy;
        configuredKey = key;
    }

    function _proxyAddress() internal view override returns (address) {
        return configuredProxy;
    }

    function _privateKey() internal view override returns (uint256) {
        return configuredKey;
    }
}

contract UpgradeScriptTest is Test {
    bytes32 constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    uint256 constant ADMIN_KEY = 0x456;

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
        UpgradeScriptHarness script = new UpgradeScriptHarness();
        script.configure(proxy, 0x123);
        uint64 nonceBefore = vm.getNonce(vm.addr(0x123));
        vm.expectRevert("PRIVATE_KEY is not ProxyAdmin owner");
        script.run();
        assertEq(vm.getNonce(vm.addr(0x123)), nonceBefore);
        assertEq(address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT)))), address(original));

        script.configure(proxy, ADMIN_KEY);
        script.run();
        address upgraded = address(uint160(uint256(vm.load(proxy, IMPLEMENTATION_SLOT))));
        assertNotEq(upgraded, address(original));
        assertEq(upgraded.codehash, address(original).codehash);
        assertEq(PrimusTip(proxy).owner(), address(this));
        assertEq(PrimusTip(proxy).claimFee(), 123);
        assertEq(PrimusTip(proxy).feeRecipient(), address(0xabc));
        assertEq(address(PrimusTip(proxy).primusZKTLS()), address(0xdef));

        script.configure(address(0), ADMIN_KEY);
        vm.expectRevert("TIP_PROXY_ADDRESS has no code");
        script.run();
        script.configure(address(original), ADMIN_KEY);
        vm.expectRevert("ProxyAdmin has no code");
        script.run();
    }
}
