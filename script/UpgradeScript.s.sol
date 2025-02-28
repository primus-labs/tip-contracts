// script/Upgrade.s.sol
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {PrimusTip} from "../src/PrimusTip.sol";
import "forge-std/Test.sol";

// script/Upgrade.s.sol
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the new logic contract
        PrimusTip newLogic = new PrimusTip();

        // 2. Retrieve the ProxyAdmin address and Proxy contract address
        address proxyAdminAddr = address(0x11111); // Replace with the actual ProxyAdmin address
        address proxyAddr = address(0x2222);           // Replace with the actual Proxy address

        // 3. Call the upgrade method of ProxyAdmin
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddr);
        ITransparentUpgradeableProxy proxy = ITransparentUpgradeableProxy(proxyAddr);
        proxyAdmin.upgradeAndCall(proxy, address(newLogic),"");

        console.log("Upgraded Proxy to New Logic Address: ", address(newLogic));

        vm.stopBroadcast();
    }
}