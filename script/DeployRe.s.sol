
// script/Deploy.s.sol
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {PrimusRedEnvelope} from "../src/PrimusRedEnvelope.sol";
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
        PrimusRedEnvelope logic = new PrimusRedEnvelope();

        // 4. Prepare initialization data
        bytes memory initializeData = abi.encodeWithSelector(
            PrimusRedEnvelope.initialize.selector,
            deployerAddress, // Replace with the actual owner address if needed
            zktls,
            feeRecipient,
            claimFee
        );

        // 5. Deploy TransparentUpgradeableProxy
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
            address(logic),
            deployerAddress,
            initializeData
        );

        // 6. Log contract addresses
        console.log("Logic Contract Address: ", address(logic));
        console.log("Proxy Contract Address: ", address(proxy));

        vm.stopBroadcast();
    }
}

