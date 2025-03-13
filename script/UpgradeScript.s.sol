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
        address proxyAdminAddr = address(0x7424af125ca3E93b56BdC869F9D86Ef20666dF55); // Replace with the actual ProxyAdmin address
        address proxyAddr = address(0xcd1Ed9C1595A7e9DADe76808dd5e66aA95940A92);           // Replace with the actual Proxy address

        // 3. Call the upgrade method of ProxyAdmin
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddr);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(proxyAddr), address(newLogic), "");

        console.log("Upgraded Proxy to New Logic Address: ", address(newLogic));

        vm.stopBroadcast();
    }
}