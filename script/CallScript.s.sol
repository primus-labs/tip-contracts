// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PrimusTip} from "../src/PrimusTip.sol";
import {TipWithdrawInfo, TipRecord, TipRecipient} from "../src/types/Common.sol";

contract CallScript is Script {
    function run() public {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        //address senderAddress = vm.addr(senderPrivateKey);
        vm.startBroadcast(senderPrivateKey);

        // monad testnet
        // PrimusTip primusTip = PrimusTip(address(0xcd1Ed9C1595A7e9DADe76808dd5e66aA95940A92));

        // bsc testnet
        PrimusTip primusTip = PrimusTip(address(0x1C5bfc91789DB3130A07a06407E02745945C3218));

        // string[] memory sourceNames = new string[](2);
        // sourceNames[0] = "tiktok";
        // sourceNames[1] = "x";
        // string[] memory urls = new string[](2);
        // urls[0] = "https://www.tiktok.com/passport/web/account/info/";
        // urls[1] = "https://api.x.com/1.1/account/settings.json";
        // string[] memory jsonPaths = new string[](2);
        // jsonPaths[0] = "$.data.username";
        // jsonPaths[1] = "$.screen_name";

        // primusTip.addBatchIdSource(sourceNames, urls, jsonPaths);

        // string[] memory sourceNames = new string[](1);
        // sourceNames[0] = "google account";
        // string[] memory urls = new string[](1);
        // urls[0] = "https://developers.google.com/_d/profile/user";
        // string[] memory jsonPaths = new string[](1);
        // jsonPaths[0] = "$[2]";

        // string[] memory sourceNames = new string[](1);
        // sourceNames[0] = "xiaohongshu";
        // string[] memory urls = new string[](1);
        // urls[0] = "https://edith.xiaohongshu.com/api/sns/web/v2/user/me";
        // string[] memory jsonPaths = new string[](1);
        // jsonPaths[0] = "$.data.red_id";

        // primusTip.addBatchIdSource(sourceNames, urls, jsonPaths);

        // primusTip.setWithdrawDelay(300);
        console.log("withdrawDelay: ", primusTip.withdrawDelay());
        console.log("feeRecipient: ", primusTip.feeRecipient());
        console.log("fee: ", primusTip.claimFee());

        // primusTip.setFeeRecipient(address(0x9717BdADb90a18e040e835b665f9E51eAa101ab1));
        // primusTip.setClaimFee(3000000000000000);

        // TipRecord[] memory tipRecord = primusTip.getTipRecords(TipRecipient("x", "e"));
        // console.log("tipRecord length=", tipRecord.length);
        //console.log("tipRecord[0].timestamp=", tipRecord[0].timestamp);

        // TipWithdrawInfo[] memory recipients = new TipWithdrawInfo[](1);
        // TipWithdrawInfo memory recipient = TipWithdrawInfo("x", "wenjun_yuan1", 1744282624);
        // recipients[0] = recipient;
        // primusTip.tipperWithdraw(recipients);

        vm.stopBroadcast();
    }
}
