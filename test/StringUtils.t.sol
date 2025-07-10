// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {StringUtils} from "../src/utils/StringUtils.sol";
import "../src/utils/JsonParser.sol";


contract StringUtilsTest is Test {
    using StringUtils for string;
    using JsonParser for string;


    function setUp() public {

    }

    function testStr() pure public{
        string memory text = "https://x.com/i/api/graphql/jUKA--0QkqGIFhmfRZdWrQ/UserByScreenName?variables=%7B%22screen_name";
        string memory baseUrl = text.extractStr("?");
        console.log("baseUrl",baseUrl);
        assertEq(baseUrl,"https://x.com/i/api/graphql/jUKA--0QkqGIFhmfRZdWrQ/UserByScreenName");

        bool  result = baseUrl.suffixWith("UserByScreenName");
        console.log("result",result);
        assertTrue(result);
        result = baseUrl.suffixWith("NoExist");
        console.log("result2",result);
        assertFalse(result);

    }

    function testSplitStr() pure public{
        string memory text = "[{\"op\":\"STREQ\",\"field\":\"$.data.user.result.relationship_perspectives.following\",\"value\":\"true\"},{\"op\":\"STREQ\",\"field\":\"$.data.user.result.core.screen_name\",\"value\":\"primus_labs\"},{\"op\":\"REVEAL_STRING\",\"field\":\"$.screen_name\"}]";
        string[] memory strs = text.split("},{");
        for (uint i=0; i<strs.length; i++) {
            string[] memory keys = new string[](3);
            keys[0] = "op";
            keys[1] = "field";
            keys[2] = "value";
            string[] memory values = strs[i].extractArrayValue(keys);
            console.log("op:",values[0]);
            console.log("field:",values[1]);
            console.log("value:",values[2]);
        }
    }
}