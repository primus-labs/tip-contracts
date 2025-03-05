
// script/Deploy.s.sol
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {PrimusTip} from "../src/PrimusTip.sol";
import "forge-std/Test.sol";

contract DeployScript is Script {
    function run() external {
        // 1. Get private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        address feeRecipient = vm.envAddress("FEE_RECIPIENT");
        address zktls = vm.envAddress("ZKTLS_ADDRESS");
        uint256 claimFee = vm.envUint("CLAIM_FEE");
        vm.startBroadcast(deployerPrivateKey);

        // 2. Deploy logic contract (implementation)
        PrimusTip logic = new PrimusTip();

        // 3. Deploy ProxyAdmin
        ProxyAdmin proxyAdmin = new ProxyAdmin(deployerAddress);

        // 4. Prepare initialization data
        bytes memory initializeData = abi.encodeWithSelector(
            PrimusTip.initialize.selector,
            deployerAddress, // Replace with the actual owner address if needed
            zktls,
            feeRecipient,
            claimFee
        );

        // 5. Deploy TransparentUpgradeableProxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(logic),
            address(proxyAdmin),
            initializeData
        );

        // 6. Log contract addresses
        console.log("Logic Contract Address: ", address(logic));
        console.log("Proxy Admin Address: ", address(proxyAdmin));
        console.log("Proxy Contract Address: ", address(proxy));

        vm.stopBroadcast();
    }
}

