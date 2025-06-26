// script/Upgrade.s.sol
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {PrimusRedEnvelope} from "../src/PrimusRedEnvelope.sol";
import "forge-std/Test.sol";

// script/Upgrade.s.sol
import {ProxyAdmin} from  "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy the new logic contract
        PrimusRedEnvelope newLogic = new PrimusRedEnvelope();

        // pharos
        address proxyAdminAddr = address(0x8e1D6B278D4304D7cb5FEfe9D4C8117DAf99F822);
        address proxyAddr = address(0x673D74d95A35B26804475066d9cD1DA3947f4eC3);

        // 3. Call the upgrade method of ProxyAdmin
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddr);
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(proxyAddr), address(newLogic), "");

        console.log("Upgraded Proxy to New Logic Address: ", address(newLogic));

        vm.stopBroadcast();
    }
}