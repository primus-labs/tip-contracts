// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

interface IOwnership {
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}

contract QueryOwners is Script {
    // bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function run() public virtual {
        address[4] memory targets = _targets();
        console.log("Chain ID:", block.chainid);
        _printOwners(targets);
    }

    // Order: Tip business, Tip ProxyAdmin, RedEnvelope business, RedEnvelope ProxyAdmin.
    function _targets() internal view returns (address[4] memory targets) {
        targets[0] = vm.envAddress("TIP_PROXY_ADDRESS");
        targets[2] = vm.envAddress("RED_ENVELOPE_PROXY_ADDRESS");
        require(targets[0] != targets[2], "Proxy addresses must differ");
        targets[1] = _proxyAdmin(targets[0]);
        targets[3] = _proxyAdmin(targets[2]);
    }

    function _proxyAdmin(address proxy) internal view returns (address admin) {
        require(proxy.code.length > 0, "Proxy address has no code");
        admin = address(uint160(uint256(vm.load(proxy, ADMIN_SLOT))));
        require(admin.code.length > 0, "ProxyAdmin address has no code");
    }

    function _printOwners(address[4] memory targets) internal view {
        string[4] memory labels =
            ["PrimusTip proxy", "PrimusTip ProxyAdmin", "PrimusRedEnvelope proxy", "PrimusRedEnvelope ProxyAdmin"];
        for (uint256 i; i < targets.length; i++) {
            console.log(labels[i], targets[i]);
            console.log("  owner:", IOwnership(targets[i]).owner());
        }
        console.log("PrimusTip feeRecipient:", IFeeRecipient(targets[0]).feeRecipient());
        console.log("PrimusRedEnvelope feeRecipient:", IFeeRecipient(targets[2]).feeRecipient());
    }
}

interface IFeeRecipient {
    function feeRecipient() external view returns (address);
}
