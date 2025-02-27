
// script/Deploy.s.sol
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PrimusTip} from "../src/PrimusTip.sol";
import "forge-std/Test.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        //address deployerAddress = vm.addr(deployerPrivateKey);
        address admin = vm.envAddress("ADMIN_ADDRESS");
        address zktls = vm.envAddress("ZKTLS_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deployment of Logic Contracts
        PrimusTip implementation = new PrimusTip();
        
        // 2. Deployment Proxy Contract
        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                PrimusTip.initialize.selector,
                admin,
                zktls
            )
        );

        vm.stopBroadcast();

        // Output Deployment Results
        console.log("Implementation address:", address(implementation));
        console.log("Proxy address:", address(proxy));
    }
}

