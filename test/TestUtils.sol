// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "src/types/Common.sol";
import "src/utils/StringUtils.sol";

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {
    Attestation,
    AttNetworkRequest,
    AttNetworkResponseResolve,
    Attestor,
    IPrimusZKTLS
} from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";

library TestUtils {
    using StringUtils for string;

    function _createTiktokAttestation()
        internal
        pure
        returns (Attestation memory att, string memory idSource, string memory id)
    {
        idSource = "tiktok";
        id = "fksyuan";
        address receiptAddr = stringToAddress("0x7ab44DE0156925fe0c24482a2cDe48C465e47573");
        AttNetworkResponseResolve[] memory response = new AttNetworkResponseResolve[](1);
        response[0] =
            AttNetworkResponseResolve({keyName: "username", parseType: "jsonpath", parsePath: "$.data.username"});

        Attestor[] memory attesters = new Attestor[](1);
        address addr = stringToAddress("0xdb736b13e2f522dbe18b2015d0291e4b193d8ef6");
        attesters[0] = Attestor({attestorAddr: addr, url: "https://primuslabs.xyz"});

        AttNetworkRequest memory request = AttNetworkRequest({
            url: "https://www.tiktok.com/passport/web/account/info/?WebIdLastTime=1733992482&aid=1459&app_language=en&app_name=tiktok_web&browser_language=en-GB-oxendict&browser_name=Mozilla&browser_online=true&browser_platform=MacIntel&browser_version=5.0%20%28Macintosh%3B%20Intel%20Mac%20OS%20X%2010_15_7%29%20AppleWebKit%2F537.36%20%28KHTML%2C%20like%20Gecko%29%20Chrome%2F132.0.0.0%20Safari%2F537.36&channel=tiktok_web&cookie_enabled=true&data_collection_enabled=true&device_id=7447440952928912914&device_platform=web_pc&focus_state=true&from_page=video&history_len=2&is_fullscreen=false&is_page_visible=true&odinId=7316364920953930757&os=mac&priority_region=&referer=&region=JP&screen_height=900&screen_width=1440&tz_name=Asia%2FShanghai&user_is_login=true&webcast_language=en&msToken=NrdkcVqela5VoeEu_UTmbqWImsHXs7pH4lznkqUTAYmGUDIfkVuAKidYtPPT4uurs6E5zEr6hgH4PIiSGmwHAdasjzqU_t32i11t6ttzYXu6vnGLARFHvih4HpaFiypvxeMVOHUgEdozqExEnZGwbKCkBHI=&X-Bogus=DFSzswVOF9TANyy3tDY4pfLNKBPp&_signature=_02B4Z6wo00001Oq9JxQAAIDDuEIHDW9Ft8zqvSOAAF0X59",
            header: "",
            method: "GET",
            body: ""
        });

        bytes[] memory sigBytes = new bytes[](1);
        sigBytes[0] = bytes(
            "0x864997e50534f11042e2e8ad177d7d0bc9bbf49e050f04e89cf88071e2c2e3821dab1df547307881cc5572c5f2981e9545b2d861685844d63bf703f5381bfc201b"
        );
        att = Attestation({
            recipient: receiptAddr,
            request: request,
            reponseResolve: response,
            data: "",
            attConditions: "[{\"op\":\"STREQ\",\"field\":\"$.data.username\",\"value\":\"fksyuan\"}]",
            timestamp: 1740554854743,
            additionParams: "{\"algorithmType\":\"proxytls\"}",
            attestors: attesters,
            signatures: sigBytes
        });

        return (att, "tiktok", "fksyuan");
    }

    function _createXAttestation()
        internal
        pure
        returns (Attestation memory att, string memory idSource, string memory id)
    {
        idSource = "x";
        id = "wenjun_yuan1";
        address receiptAddr = stringToAddress("0x7ab44DE0156925fe0c24482a2cDe48C465e47573");
        AttNetworkResponseResolve[] memory response = new AttNetworkResponseResolve[](1);
        response[0] =
            AttNetworkResponseResolve({keyName: "screen_name", parseType: "jsonpath", parsePath: "$.screen_name"});

        Attestor[] memory attesters = new Attestor[](1);
        address addr = stringToAddress("0xdb736b13e2f522dbe18b2015d0291e4b193d8ef6");
        attesters[0] = Attestor({attestorAddr: addr, url: "https://primuslabs.xyz"});

        AttNetworkRequest memory request = AttNetworkRequest({
            url: "https://api.x.com/1.1/account/settings.json?include_ext_sharing_audiospaces_listening_data_with_followers=true&include_mention_filter=true&include_nsfw_user_flag=true&include_nsfw_admin_flag=true&include_ranked_timeline=true&include_alt_text_compose=true&ext=ssoConnections&include_country_code=true&include_ext_dm_nsfw_media_filter=true",
            header: "",
            method: "GET",
            body: ""
        });

        bytes[] memory sigBytes = new bytes[](1);
        sigBytes[0] = bytes(
            "0xe0617d7d4b6f016aa68bed6d6afc8e1f28e3a2bf5ab53bd7822ceef9bef388b94f27097a1b3db5a451d3f7e3647e9f847c94e9de266b9194692a8e87519af8a01b"
        );
        att = Attestation({
            recipient: receiptAddr,
            request: request,
            reponseResolve: response,
            data: "",
            attConditions: "[{\"op\":\"STREQ\",\"field\":\"$.screen_name\",\"value\":\"wenjun_yuan1\"}]",
            timestamp: 1740548090903,
            additionParams: "{\"algorithmType\":\"proxytls\"}",
            attestors: attesters,
            signatures: sigBytes
        });
        return (att, idSource, id);
    }

    function _createInvalidAttestation()
        internal
        pure
        returns (Attestation memory att, string memory idSource, string memory id)
    {
        idSource = "github";
        id = "invalid_user";
        AttNetworkResponseResolve[] memory response = new AttNetworkResponseResolve[](1);
        response[0] = AttNetworkResponseResolve({keyName: "screen_name", parseType: "", parsePath: "$.screen_name"});

        Attestor[] memory attesters = new Attestor[](1);
        address addr = stringToAddress("0xdb736b13e2f522dbe18b2015d0291e4b193d8ef6");
        attesters[0] = Attestor({attestorAddr: addr, url: "https://primuslabs.xyz"});

        AttNetworkRequest memory request = AttNetworkRequest({
            url: "https://api.x.com/1.1/account/settings.json?include_ext_sharing_audiospaces_listening_data_with_followers=true&include_mention_filter=true&include_nsfw_user_flag=true&include_nsfw_admin_flag=true&include_ranked_timeline=true&include_alt_text_compose=true&ext=ssoConnections&include_country_code=true&include_ext_dm_nsfw_media_filter=true",
            header: "",
            method: "GET",
            body: ""
        });

        bytes[] memory sigBytes = new bytes[](1);
        sigBytes[0] = bytes(
            "0xe0617d7d4b6f016aa68bed6d6afc8e1f28e3a2bf5ab53bd7822ceef9bef388b94f27097a1b3db5a451d3f7e3647e9f847c94e9de266b9194692a8e87519af8a01b"
        );
        att = Attestation({
            recipient: address(0),
            request: request,
            reponseResolve: response,
            data: "{\"screen_name\":\"wenjun_yuan1\"}",
            attConditions: "[{\"op\":\"REVEAL_STRING\",\"field\":\"$.screen_name\"}]",
            timestamp: 1740548090903,
            additionParams: "{\"algorithmType\":\"proxytls\"}",
            attestors: attesters,
            signatures: sigBytes
        });
        return (att, idSource, id);
    }

    function stringToAddress(string memory _addressString) internal pure returns (address) {
        bytes memory addressBytes = bytes(_addressString);
        require(addressBytes.length == 42, "Invalid address length");
        address addr;
        assembly {
            addr := mload(add(_addressString, 20))
        }
        return addr;
    }

    function uintToString(uint256 _value) internal pure returns (string memory) {
        if (_value == 0) {
            return "0";
        }
        uint256 temp = _value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (_value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + _value % 10)); // 48 是 '0' 的 ASCII 码
            _value /= 10;
        }
        return string(buffer);
    }
}
