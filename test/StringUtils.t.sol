import "forge-std/Test.sol";
import "forge-std/console.sol";
import {StringUtils} from "../src/utils/StringUtils.sol";
    using StringUtils for string;
contract StringUtilsTest is Test {

    function setUp() public {

    }

    function testStr() public{
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
}