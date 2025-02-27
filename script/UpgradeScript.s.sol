// script/Upgrade.s.sol
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {PrimusTip} from "../src/PrimusTip.sol";
import "forge-std/Test.sol";

// script/Upgrade.s.sol
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol"; 

contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");
        address zktls = vm.envAddress("ZKTLS_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy New Version Logic Contracts
        PrimusTip newImplementation = new PrimusTip();
        
        // Initialize Data
        bytes memory initializeData = abi.encodeWithSelector(
            PrimusTip.initialize.selector,
            deployerAddress,// Replace with the actual owner address if needed
            zktls
        );

        // Convert to UUPS interface
        UUPSUpgradeable proxy = UUPSUpgradeable(payable(proxyAddress));
        
        // Execute upgrades
        proxy.upgradeToAndCall(address(newImplementation), initializeData);

        vm.stopBroadcast();
    }
}