
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
            deployerAddress,
            initializeData
        );

        // 6. Log contract addresses
        console.log("Logic Contract Address: ", address(logic));
        console.log("Proxy Contract Address: ", address(proxy));

        string[] memory sourceNames = new string[](4);
        sourceNames[0] = "tiktok";
        sourceNames[1] = "x";
        sourceNames[2] = "google account";
        sourceNames[3] = "xiaohongshu";
        string[] memory urls = new string[](4);
        urls[0] = "https://www.tiktok.com/passport/web/account/info/";
        urls[1] = "https://api.x.com/1.1/account/settings.json";
        urls[2] = "https://developers.google.com/_d/profile/user";
        urls[3] = "https://edith.xiaohongshu.com/api/sns/web/v2/user/me";
        string[] memory jsonPaths = new string[](4);
        jsonPaths[0] = "$.data.username";
        jsonPaths[1] = "$.screen_name";
        jsonPaths[2] = "$[2]";
        jsonPaths[3] = "$.data.red_id";
        PrimusTip primusTip = PrimusTip(address(proxy));
        primusTip.addBatchIdSource(sourceNames, urls, jsonPaths);

        vm.stopBroadcast();
    }
}

