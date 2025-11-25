// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PrimusTip} from "../src/PrimusTip.sol";
import {TipWithdrawInfo, TipRecord, TipRecipient, TipToken, TipRecipientInfo} from "../src/types/Common.sol";
import {
    Attestation,
    AttNetworkRequest,
    AttNetworkResponseResolve,
    Attestor,
    IPrimusZKTLS
} from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";

contract CallScript is Script {
    function run() public {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        //address senderAddress = vm.addr(senderPrivateKey);
        vm.startBroadcast(senderPrivateKey);

        // monad testnet
        // PrimusTip primusTip = PrimusTip(address(0xcd1Ed9C1595A7e9DADe76808dd5e66aA95940A92));

        // bsc testnet
        // PrimusTip primusTip = PrimusTip(address(0x1C5bfc91789DB3130A07a06407E02745945C3218));

        // bsc mainnet
        // PrimusTip primusTip = PrimusTip(address(0x1fb86db904caF7c12100EA64024E5dfd7505E484));

        // pharos testnet
        // PrimusTip primusTip = PrimusTip(address(0xD17512B7EC12880Bd94Eca9d774089fF89805F02));

        // pharos atlantic testnet
        PrimusTip primusTip = PrimusTip(address(0x3A83cAB6da93210933D94fC68A093a6983c2BCD1));

        // base sepolia testnet
        // PrimusTip primusTip = PrimusTip(address(0x4E78940F0019EbAEDc6F4995D7B8ABf060F7a341));

        // base mainnet
        // PrimusTip primusTip = PrimusTip(address(0xa2e0700a269Be3158c81E4739518b324d4398588));

        // monad mainnet
        // PrimusTip primusTip = PrimusTip(address(0xa2e0700a269Be3158c81E4739518b324d4398588));
        // address primusTipAddres = address(0xa2e0700a269Be3158c81E4739518b324d4398588);

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


    //  for monad mainnet
    //    bytes memory data = abi.encodeWithSelector(PrimusTip.setWithdrawDelay.selector, uint256(30 days));
    //    (bool ok, ) = primusTipAddres.call{gas: 60_000}(data);
    //    require(ok, "setWithdrawDelay failed");


        console.log("withdrawDelay: ", primusTip.withdrawDelay());
        console.log("feeRecipient: ", primusTip.feeRecipient());
        console.log("fee: ", primusTip.claimFee());
        // console.log("primusZKTLS:", address(primusTip.primusZKTLS()));

        // primusTip.setFeeRecipient(address(0x9717BdADb90a18e040e835b665f9E51eAa101ab1));
       // primusTip.setClaimFee(1000000000000000);


    //  for monad mainnet
    //    bytes memory data = abi.encodeWithSelector(PrimusTip.setClaimFee.selector, uint256(3000000000000000000));
    //    (bool ok, ) = primusTipAddres.call{gas: 60_000}(data);
    //    require(ok, "setClaimFee failed");


        // console.log("fee: ", primusTip.claimFee());

        // TipRecord[] memory tipRecord = primusTip.getTipRecordsPaginated(TipRecipient("x", "avzcrypto"), 0, 20);
        // console.log("tipRecord length=", tipRecord.length);
        // console.log("tipRecord[0].timestamp=", tipRecord[0].timestamp);
        // console.log("tipRecord[0].amount=", tipRecord[0].amount);

        // uint256 recordLen = primusTip.getTipRecordsLength(TipRecipient("x", "avzcrypto"));
        // console.log("recordLen=", recordLen);

        // uint256 amount = primusTip.getTipRecordsNativeAmount(TipRecipient("x", "avzcrypto"));
        // console.log("amount=", amount);

        // (address[] memory token, uint256[] memory balance) = primusTip.getTipTokenStats(TipRecipient("x", "avzcrypto"));
        // for (uint256 i = 0; i < token.length; i++) {
        //     console.log("address=", token[i]);
        //     console.log("balance=", balance[i]);
        // }

        // Attestation memory attestation;
        // string memory idSource = "x";
        // string memory id = "wenjun_yuan1";
        // (attestation,  idSource, id) = _createXAttestation();
        // primusTip.claimBySource{value: 0.0001 ether}(idSource, attestation);

        // TipWithdrawInfo[] memory recipients = new TipWithdrawInfo[](1);
        // TipWithdrawInfo memory recipient = TipWithdrawInfo("x", "wenjun_yuan1", 1744282624);
        // recipients[0] = recipient;
        // primusTip.tipperWithdraw(recipients);

        // TipToken memory token = TipToken({
        //     tokenType: 1,
        //     tokenAddress: address(0x0000000000000000000000000000000000000000)
        // });
        // TipRecipientInfo memory recipient = TipRecipientInfo({
        //     idSource: "x",
        //     id: "wenjun_yuan1",
        //     amount: 10000000000000000,
        //     nftIds: new uint256[](0)
        // });
        // primusTip.tip{value: 10000000000000000}(token, recipient);

        vm.stopBroadcast();
    }


    function _createXAttestation() private pure returns
    (
        Attestation memory att,
        string memory idSource,
        string memory id
    ) {
        idSource = "x";
        id = "wenjun_yuan1";
        address receiptAddr = address(0xDB736B13E2f522dBE18B2015d0291E4b193D8eF6);
        AttNetworkResponseResolve[] memory response = new AttNetworkResponseResolve[](1);
            response[0] = AttNetworkResponseResolve({
                keyName: "",
                parseType: "",
                parsePath: "$.screen_name"
            });

        Attestor[] memory attesters = new Attestor[](1);
        address addr = address(0xDB736B13E2f522dBE18B2015d0291E4b193D8eF6);
        attesters[0] = Attestor({
            attestorAddr:addr,
            url:"https://primuslabs.xyz"
        });

        AttNetworkRequest memory request = AttNetworkRequest({
                url: "https://api.x.com/1.1/account/settings.json?include_ext_sharing_audiospaces_listening_data_with_followers=true&include_mention_filter=true&include_nsfw_user_flag=true&include_nsfw_admin_flag=true&include_ranked_timeline=true&include_alt_text_compose=true&ext=ssoConnections&include_country_code=true&include_ext_dm_nsfw_media_filter=true",
                header: "",
                method: "GET",
                body: ""
        });

        bytes[] memory sigBytes = new bytes[](1);
        sigBytes[0] = hexStringToBytes("0xb041c8692c9331b438b0c639827ce4506818bde074e97242bfc2bab44e512b445363df2d7c9ae5b7d617fb63c565623cf50f92b45adc9539d1f9eca223de78771b");
        att = Attestation({
            recipient: receiptAddr,
            request: request,
            reponseResolve: response,
            data: "{}",
            attConditions: "[{\"op\":\"STREQ\",\"field\":\"$.screen_name\",\"value\":\"wenjun_yuan1\"}]",
            timestamp:1747308230190,
            additionParams:"{\"algorithmType\":\"proxytls\"}",
            attestors: attesters,
            signatures: sigBytes
        });
        console.log("attestation.signatures.length", att.signatures.length);
        console.log("attestation.signatures[0].length", att.signatures[0].length);
        return (att, idSource, id);
    }

    function hexStringToBytes(string memory s) public pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        uint offset = 0;

        if (ss.length >= 2 && ss[0] == "0" && ss[1] == "x") {
            offset = 2; // skip "0x"
        }

        require((ss.length - offset) % 2 == 0, "Hex string must have even length");

        bytes memory result = new bytes((ss.length - offset) / 2);
        for (uint i = 0; i < result.length; i++) {
            result[i] = bytes1(
                (fromHexChar(uint8(ss[offset + 2 * i])) << 4) |
                fromHexChar(uint8(ss[offset + 2 * i + 1]))
            );
        }

        return result;
    }

    function fromHexChar(uint8 c) internal pure returns (uint8) {
        if (bytes1(c) >= "0" && bytes1(c) <= "9") return c - uint8(bytes1("0"));
        if (bytes1(c) >= "a" && bytes1(c) <= "f") return 10 + c - uint8(bytes1("a"));
        if (bytes1(c) >= "A" && bytes1(c) <= "F") return 10 + c - uint8(bytes1("A"));
        revert("Invalid hex character");
    }
}
