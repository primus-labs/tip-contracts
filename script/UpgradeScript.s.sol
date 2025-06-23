// script/Upgrade.s.sol
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {PrimusTip} from "../src/PrimusTip.sol";
import "forge-std/Test.sol";

// script/Upgrade.s.sol
import {ProxyAdmin} from  "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the new logic contract
        PrimusTip newLogic = new PrimusTip();

        // 2. Retrieve the ProxyAdmin address and Proxy contract address
        // bsc mainnet
        // address proxyAdminAddr = address(0xb910D329B9d3ecEdd636DD99aDc82d5a6B270AF9); // Replace with the actual ProxyAdmin address
        // address proxyAddr = address(0x1fb86db904caF7c12100EA64024E5dfd7505E484);           // Replace with the actual Proxy address

        // pharos
        address proxyAdminAddr = address(0x9eC27C173bDfc7CF1C6B9cE550eD2A34F2868716);
        address proxyAddr = address(0xD17512B7EC12880Bd94Eca9d774089fF89805F02);

        // 3. Call the upgrade method of ProxyAdmin
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddr);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(proxyAddr), address(newLogic), "");

        console.log("Upgraded Proxy to New Logic Address: ", address(newLogic));

        vm.stopBroadcast();
    }
}