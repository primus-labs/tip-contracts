// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PrimusRedEnvelope} from "../src/PrimusRedEnvelope.sol";
import {TipWithdrawInfo, TipRecord, TipRecipient, RERecord} from "../src/types/Common.sol";
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

        // pharos testnet
        // PrimusRedEnvelope primusRe = PrimusRedEnvelope(address(0x673D74d95A35B26804475066d9cD1DA3947f4eC3));

        // bsc testnet
        // PrimusRedEnvelope primusRe = PrimusRedEnvelope(address(0xd2357F600D1B7d36E065C8fE1D5A66E43De18F56));

        // monad testnet
        // PrimusRedEnvelope primusRe = PrimusRedEnvelope(address(0x5508fC45d930B5dE36647Dbbe5B9414e43C4F614));

         // base sepolia
        PrimusRedEnvelope primusRe = PrimusRedEnvelope(address(0xA33Ed35460C3d06094693956B2d7Cd1a9e7A39a8));

        // uint256 prevrandao;
        // uint256 blocknumber;
        // (prevrandao, blocknumber) = primusRe.getPrev();
        // console.log("block.prevrandao:", prevrandao);
        // console.log("blocknumber:", blocknumber);

        console.log("withdrawDelay: ", primusRe.withdrawDelay());
        console.log("feeRecipient: ", primusRe.feeRecipient());
        console.log("fee: ", primusRe.claimFee());
        // primusRe.setWithdrawDelay(300);
        // console.log("withdrawDelay: ", primusRe.withdrawDelay());
        // primusRe.setClaimFee(150000000000000);
        // console.log("fee: ", primusRe.claimFee());

        // RERecord memory record = primusRe.getREInfo(bytes32(0x82eba839abb7ae4fa7d9625379c6036355d53ce6eb800dc66ed2c573f306f82e));
        // console.log("record remainingAmount:", record.remainingAmount);
        // console.log("record remainingNumber:", record.remainingNumber);
        // console.log("record reSender:", record.reSender);
        // console.log("record.timestamp:", record.timestamp);
        // console.log("record timestamp withdrawDelay:", record.timestamp + primusRe.withdrawDelay());
        // console.log("block.timestamp:", block.timestamp);
        // console.log("amount:", record.amount);
        // console.log("number:", record.number);


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
