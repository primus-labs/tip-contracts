// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/PrimusTip.sol";
import "src/types/Common.sol";
import "src/utils/StringUtils.sol";
import "./PrimusTestNFT.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {
Attestation as PrimusAttestation,
AttNetworkRequest,
AttNetworkResponseResolve,
Attestor,
IPrimusZKTLS
} from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";
import {PrimusRedEnvelope} from "../src/PrimusRedEnvelope.sol";

uint32 constant RE_RANDOM = 0;
uint32 constant RE_AVERAGE = 1;

uint32 constant FOLLOWING_CHECK_TYPE = 0;
string constant following_screen_name = "primus_labs";

bytes32 constant eventSig = keccak256("RESendEvent(bytes32,address,uint32,address,uint256,uint32,uint32,uint64)");
bytes32 constant claimSig = keccak256("REClaimEvent(bytes32,address,string,uint256,uint32,uint64,address)");
bytes32 constant withdrawSig = keccak256("RESWithdrawEvent(bytes32,address,uint256,uint32,uint64)");

contract ERC20Mock is IERC20 {

    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function totalSupply() external view override returns (uint256) {}
}

contract PrimusZKTLSMock is IPrimusZKTLS {
    function verifyAttestation(Attestation calldata) external pure override {
        return;
    }
}

contract PrimusRedEnvelopeTest is Test {
    using StringUtils for string;
    PrimusRedEnvelope public primusRedEnvelope;
    PrimusZKTLSMock public primusZKTLS;
    address public owner = address(1);
    address public tipper = address(2);
    address public feeRecipient = address(0x456);
    address public user = address(0x789);
    address public recipientAddr = stringToAddress("0x7ab44DE0156925fe0c24482a2cDe48C465e47573");
    address public erc20Token = address(4);
    address public nftTokenAddr = address(5);

    function setUp() public {
        vm.startPrank(owner);
        primusZKTLS = new PrimusZKTLSMock();
        primusRedEnvelope = new PrimusRedEnvelope();
        console.log("primusRedEnvelope=", address(primusRedEnvelope));
        primusRedEnvelope.initialize(owner, primusZKTLS, feeRecipient, 0);
        vm.stopPrank();
    }


    function testReSend() public {
        vm.startPrank(tipper);
        vm.recordLogs();
        vm.deal(tipper, 1 ether);
        TipToken memory nativeToken = TipToken(NATIVE_TYPE, erc20Token);
        uint32 number = 1;
        RESendParam memory reSendParam = RESendParam(RE_RANDOM, number, 100, address(primusRedEnvelope), "");
        // Call contract
        (bool success, bytes memory data) = address(primusRedEnvelope).call{value: 100}(
            abi.encodeWithSelector(primusRedEnvelope.reSend.selector, nativeToken, reSendParam)
        );
        // Resolve evnt
        console.logBytes32(eventSig);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        console.log("logs.length=", logs.length);
        assertEq(logs.length, 1);
        console.logBytes32(logs[0].topics[0]);
        for (uint256 i = 0; i < logs.length; ++i) {
            Vm.Log memory log = logs[i];
            if (log.topics[0] == eventSig) {
                bytes32 id = log.topics[1];
                (address reSender, uint32 tokenType, address tokenAddress, uint256 amount, uint32 reType, uint32 number, uint64 timestamp) = abi.decode(log.data, (address, uint32, address, uint256, uint32, uint32, uint64));

                console.log("id=", uintToString(uint256(id)));
                assertEq(amount, 100);
            }
        }
        vm.stopPrank();
    }

    function testReClaim() public {
        vm.startPrank(tipper);
        vm.recordLogs();
        //-----Send red packet
        // Transfer 1 eth to tipper
        vm.deal(tipper, 1 ether);
        TipToken memory nativeToken = TipToken(NATIVE_TYPE, erc20Token);
        uint32 number = 2;
        bytes memory params = abi.encode(FOLLOWING_CHECK_TYPE, following_screen_name);
        RESendParam memory reSendParam = RESendParam(RE_RANDOM, number, 100, address(primusRedEnvelope), params);
        (bool success, bytes memory data) = address(primusRedEnvelope).call{value: 100}(
            abi.encodeWithSelector(primusRedEnvelope.reSend.selector, nativeToken, reSendParam)
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Vm.Log memory log = logs[0];
        bytes32 id = log.topics[1];
        console.log("id=", uintToString(uint256(id)));
        //----Claim red packet
        Attestation memory attestation;
        string memory idSource = "x";
        string memory sourceUserId = "goose_eggsss";
        (attestation, idSource, sourceUserId) = mockAttestation();
        console.log("attestation.recipient=", attestation.recipient);
        console.log("before claim:", attestation.recipient.balance);

        primusRedEnvelope.reClaim(id, attestation);
        Vm.Log[] memory claimLogs = vm.getRecordedLogs();
        console.log("claimLogs.length=", claimLogs.length);
        assertEq(claimLogs.length, 1);
        console.logBytes32(claimSig);
        assertEq(claimLogs[0].topics[0], claimSig);
        console.log("after claim:", attestation.recipient.balance);
        assertNotEq(attestation.recipient.balance, 0);
        vm.stopPrank();
    }

    function testReWithdraw() public {
        vm.startPrank(tipper);
        vm.recordLogs();
        //-----Send red packet
        // Transfer 1 eth to tipper
        vm.deal(tipper, 1 ether);
        uint256 balanceBefore = tipper.balance;
        TipToken memory nativeToken = TipToken(NATIVE_TYPE, erc20Token);
        uint32 number = 2;
        bytes memory params = abi.encode(FOLLOWING_CHECK_TYPE, following_screen_name);
        RESendParam memory reSendParam = RESendParam(RE_RANDOM, number, 100, address(primusRedEnvelope), params);
        (bool success, bytes memory data) = address(primusRedEnvelope).call{value: 100}(
            abi.encodeWithSelector(primusRedEnvelope.reSend.selector, nativeToken, reSendParam)
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Vm.Log memory log = logs[0];
        bytes32 id = log.topics[1];
        console.log("id=", uintToString(uint256(id)));
        //----withdraw red packet
        //require 'not expired'
        vm.expectRevert();
        primusRedEnvelope.reSenderWithdraw(id);
        vm.stopPrank();

        //update withdrawDelay
        vm.startPrank(owner);
        primusRedEnvelope.setWithdrawDelay(0);
        vm.stopPrank();
        vm.startPrank(tipper);
        console.log("before withdraw:", tipper.balance);
        primusRedEnvelope.reSenderWithdraw(id);
        Vm.Log[] memory withdrawLogs = vm.getRecordedLogs();
        console.log("withdraw.length=", withdrawLogs.length);
        assertEq(withdrawLogs.length, 1);
        console.logBytes32(withdrawSig);
        console.log("after withdraw:", tipper.balance);
        assertEq(withdrawLogs[0].topics[0], withdrawSig);
        assertEq(tipper.balance, balanceBefore);
    }


    function testClaimAndReWithdraw() public {
        vm.startPrank(tipper);
        vm.recordLogs();
        //-----Send red packet
        // Transfer 1 eth to tipper
        vm.deal(tipper, 1 ether);
        uint256 balanceBefore = tipper.balance;
        TipToken memory nativeToken = TipToken(NATIVE_TYPE, erc20Token);
        uint32 number = 2;
        bytes memory params = abi.encode(FOLLOWING_CHECK_TYPE, following_screen_name);
        RESendParam memory reSendParam = RESendParam(RE_RANDOM, number, 100, address(primusRedEnvelope), params);
        (bool success, bytes memory data) = address(primusRedEnvelope).call{value: 100}(
            abi.encodeWithSelector(primusRedEnvelope.reSend.selector, nativeToken, reSendParam)
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Vm.Log memory log = logs[0];
        bytes32 id = log.topics[1];
        console.log("id=", uintToString(uint256(id)));
        // Claim red packet
        Attestation memory attestation;
        string memory idSource = "x";
        string memory sourceUserId = "goose_eggsss";
        (attestation, idSource, sourceUserId) = mockAttestation();
        console.log("attestation.recipient=", attestation.recipient);
        console.log("before claim:", attestation.recipient.balance);

        primusRedEnvelope.reClaim(id, attestation);
        Vm.Log[] memory claimLogs = vm.getRecordedLogs();
        console.log("claimLogs.length=", claimLogs.length);
        assertEq(claimLogs.length, 1);
        console.logBytes32(claimSig);
        assertEq(claimLogs[0].topics[0], claimSig);
        console.log("after claim:", attestation.recipient.balance);
        assertNotEq(attestation.recipient.balance, 0);
        (address recipient, string memory userId, uint256 claimAmount, uint32 reIndex, uint64 timestamp) = abi.decode(claimLogs[0].data, (address, string, uint256, uint32, uint64));
        console.log("recipient=", recipient);
        console.log("claim reIndex=", reIndex);
        console.log("claimAmount claimAmount=", claimAmount);
        vm.stopPrank();

        //----withdraw red packet
        //require 'not expired'
        vm.expectRevert();
        primusRedEnvelope.reSenderWithdraw(id);
        vm.stopPrank();

        //update withdrawDelay
        vm.startPrank(owner);
        primusRedEnvelope.setWithdrawDelay(0);
        vm.stopPrank();
        vm.startPrank(tipper);
        console.log("before withdraw:", tipper.balance);
        primusRedEnvelope.reSenderWithdraw(id);
        Vm.Log[] memory withdrawLogs = vm.getRecordedLogs();
        console.log("withdraw.length=", withdrawLogs.length);
        assertEq(withdrawLogs.length, 1);
        console.logBytes32(withdrawSig);
        console.log("after withdraw:", tipper.balance);
        assertEq(withdrawLogs[0].topics[0], withdrawSig);
        assertEq(tipper.balance + claimAmount, balanceBefore);
    }

    function testUpdateWithdrawDelay() public {
        vm.expectRevert();
        primusRedEnvelope.setWithdrawDelay(0);

        vm.startPrank(owner);
        primusRedEnvelope.setWithdrawDelay(0);
        vm.stopPrank();
    }

    //-----------------help function----------------

    // Mock valid attestation
    function mockAttestation() private pure returns
    (
        Attestation memory att,
        string memory idSource,
        string memory id
    ) {
        idSource = "x";
        id = "goose_eggsss";
        address receiptAddr = address(0xB12a1f7035FdCBB4cC5Fa102C01346BD45439Adf);
        AttNetworkResponseResolve[] memory response = new AttNetworkResponseResolve[](2);
        response[0] = AttNetworkResponseResolve({
            keyName: "following",
            parseType: "",
            parsePath: "$.data.user.result.relationship_perspectives.following"
        });
        response[1] = AttNetworkResponseResolve({
            keyName: "following_screen_name",
            parseType: "",
            parsePath: "$.data.user.result.core.screen_name"
        });

        Attestor[] memory attesters = new Attestor[](1);
        address addr = stringToAddress("0xdb736b13e2f522dbe18b2015d0291e4b193d8ef6");
        attesters[0] = Attestor({
            attestorAddr: addr,
            url: "https://primuslabs.xyz"
        });

        AttNetworkRequest memory request = AttNetworkRequest({
            url: "https://x.com/i/api/graphql/jUKA--0QkqGIFhmfRZdWrQ/UserByScreenName?variables=%7B%22screen_name%22%3A%22primus_labs%22%7D&features=%7B%22responsive_web_grok_bio_auto_translation_is_enabled%22%3Afalse%2C%22hidden_profile_subscriptions_enabled%22%3Atrue%2C%22payments_enabled%22%3Afalse%2C%22profile_label_improvements_pcf_label_in_post_enabled%22%3Atrue%2C%22rweb_tipjar_consumption_enabled%22%3Atrue%2C%22verified_phone_label_enabled%22%3Afalse%2C%22subscriptions_verification_info_is_identity_verified_enabled%22%3Atrue%2C%22subscriptions_verification_info_verified_since_enabled%22%3Atrue%2C%22highlights_tweets_tab_ui_enabled%22%3Atrue%2C%22responsive_web_twitter_article_notes_tab_enabled%22%3Atrue%2C%22subscriptions_feature_can_gift_premium%22%3Atrue%2C%22creator_subscriptions_tweet_preview_api_enabled%22%3Atrue%2C%22responsive_web_graphql_skip_user_profile_image_extensions_enabled%22%3Afalse%2C%22responsive_web_graphql_timeline_navigation_enabled%22%3Atrue%7D&fieldToggles=%7B%22withAuxiliaryUserLabels%22%3Atrue%7D",
            header: "",
            method: "GET",
            body: ""
        });

        bytes[] memory sigBytes = new bytes[](1);
        sigBytes[0] = bytes("0xcdbf87ec6772ee6c734d3463b875792f5e49be43b38f76e3eeb498f4d757db34512c90c8eb78b1993d120286a4d5baa87e5a5fae01e194fe363381067e3e36981c");
        att = Attestation({
            recipient: receiptAddr,
            request: request,
            reponseResolve: response,
            data: "{\"screen_name\":\"goose_eggsss\",\"following\":\"true\",\"following_screen_name\":\"primus_labs\"}",
            attConditions: "[{\"op\":\"REVEAL_STRING\",\"field\":\"$.data.user.result.relationship_perspectives.following\"},{\"op\":\"REVEAL_STRING\",\"field\":\"$.data.user.result.core.screen_name\"},{\"op\":\"REVEAL_STRING\",\"field\":\"$.screen_name\"}]",
            timestamp: 1740548090903,
            additionParams: "{\"algorithmType\":\"proxytls\",\"requests[1].url\":\"https://api.x.com/1.1/account/settings.json?include_ext_sharing_audiospaces_listening_data_with_followers=true&include_mention_filter=true&include_nsfw_user_flag=true&include_nsfw_admin_flag=true&include_ranked_timeline=true&include_alt_text_compose=true&ext=ssoConnections&include_country_code=true&include_ext_dm_nsfw_media_filter=true\",\"requests[1].method\":\"GET\",\"requests[1].body\":\"\",\"requests[1].header\":\"\",\"reponseResolves[1][0].keyName\":\"screen_name\",\"reponseResolves[1][0].parseType\":\"\",\"reponseResolves[1][0].parsePath\":\"$.screen_name\"}",
            attestors: attesters,
            signatures: sigBytes
        });
        return (att, idSource, id);
    }

    //
    function stringToAddress(string memory _addressString) public pure returns (address) {
        bytes memory addressBytes = bytes(_addressString);
        require(addressBytes.length == 42, "Invalid address length");
        address addr;
        assembly {
            addr := mload(add(_addressString, 20))
        }
        return addr;
    }

    function uintToString(uint256 _value) public pure returns (string memory) {
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
