// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PrimusTip} from "../src/PrimusTip.sol";

contract CallScript is Script {
    function run() public {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        //address senderAddress = vm.addr(senderPrivateKey);
        vm.startBroadcast(senderPrivateKey);

        PrimusTip primusTip = PrimusTip(address(0x8F796FbE77E0c7afb695d3F7B5283989299069b9));

        string[] memory sourceNames = new string[](2);
        sourceNames[0] = "tiktok";
        sourceNames[1] = "x";
        string[] memory urls = new string[](2);
        urls[0] = "https://www.tiktok.com/passport/web/account/info/";
        urls[1] = "https://api.x.com/1.1/account/settings.json";
        string[] memory jsonPaths = new string[](2);
        jsonPaths[0] = "$.data.username";
        jsonPaths[1] = "$.screen_name";

        primusTip.addBatchIdSource(sourceNames, urls, jsonPaths);

        vm.stopBroadcast();
    }
}
