// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {PrimusTip} from "../src/PrimusTip.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeScript is Script {
    bytes32 internal constant ADMIN_SLOT = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
    bytes32 internal constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    function run() external {
        address proxyAddr = _proxyAddress();
        require(proxyAddr.code.length > 0, "TIP_PROXY_ADDRESS has no code");
        address proxyAdminAddr = address(uint160(uint256(vm.load(proxyAddr, ADMIN_SLOT))));
        require(proxyAdminAddr.code.length > 0, "ProxyAdmin has no code");
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddr);
        uint256 deployerPrivateKey = _privateKey();
        require(proxyAdmin.owner() == vm.addr(deployerPrivateKey), "PRIVATE_KEY is not ProxyAdmin owner");

        console.log("Chain ID:", block.chainid);
        console.log("Tip proxy:", proxyAddr);
        console.log("ProxyAdmin:", proxyAdminAddr);

        vm.startBroadcast(deployerPrivateKey);
        PrimusTip newLogic = new PrimusTip();
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(proxyAddr), address(newLogic), "");
        vm.stopBroadcast();

        require(
            address(uint160(uint256(vm.load(proxyAddr, IMPLEMENTATION_SLOT)))) == address(newLogic),
            "Implementation was not updated"
        );
        console.log("Upgraded implementation:", address(newLogic));
    }

    function _proxyAddress() internal virtual returns (address) {
        return vm.envAddress("TIP_PROXY_ADDRESS");
    }

    function _privateKey() internal virtual returns (uint256) {
        return vm.envUint("PRIVATE_KEY");
    }
}
