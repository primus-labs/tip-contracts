// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PrimusRedEnvelopeTest} from "./PrimusRedEnvelope.t.sol";
import {TipToken, NATIVE_TYPE, RESendParam} from "../src/types/Common.sol";
import {
    Attestation,
    AttNetworkRequest,
    AttNetworkResponseResolve,
    Attestor
} from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";

contract NativePaymentReceiver {
    uint256 public received;
    bool public reject;
    address public target;
    bytes public callback;
    bool public callbackSucceeded;
    bytes public callbackResult;

    function configure(bool reject_, address target_, bytes memory callback_) external {
        reject = reject_;
        target = target_;
        callback = callback_;
    }

    receive() external payable {
        require(!reject, "Receiver rejected ETH");
        received += msg.value; // Storage write requires more than the 2300 transfer stipend.
        if (target != address(0)) {
            (callbackSucceeded, callbackResult) = target.call(callback);
        }
    }
}

contract PrimusRedEnvelopeNativePaymentsTest is PrimusRedEnvelopeTest {
    function _sendNativeEnvelope(address sender, uint256 totalAmount, uint32 number, uint32 reType)
        internal
        returns (bytes32 reId)
    {
        vm.deal(sender, totalAmount + 1 ether);
        vm.prank(sender);
        bytes memory checkParams = abi.encode(0, "primus_labs");
        RESendParam memory sendParam = RESendParam({
            reType: reType,
            number: number,
            amount: totalAmount,
            checkContract: address(0),
            checkParams: checkParams
        });
        TipToken memory token = TipToken({tokenType: NATIVE_TYPE, tokenAddress: address(0)});
        primusRedEnvelope.reSend{value: totalAmount}(token, sendParam);
        reId = keccak256(abi.encodePacked(block.chainid, uint256(1)));
    }

    function _mockAttestationFor(address recipient) internal pure returns (Attestation memory att) {
        AttNetworkResponseResolve[] memory response = new AttNetworkResponseResolve[](2);
        response[0] = AttNetworkResponseResolve({
            keyName: "following",
            parseType: "",
            parsePath: "$.data.user.result.relationship_perspectives.following"
        });
        response[1] = AttNetworkResponseResolve({
            keyName: "FOLLOWING_SCREEN_NAME",
            parseType: "",
            parsePath: "$.data.user.result.core.screen_name"
        });

        Attestor[] memory attesters = new Attestor[](1);
        attesters[0] = Attestor({
            attestorAddr: address(0xDB736B13E2f522dBE18B2015d0291E4b193D8eF6),
            url: "https://primuslabs.xyz"
        });

        AttNetworkRequest memory request = AttNetworkRequest({
            url: "https://x.com/i/api/graphql/jUKA--0QkqGIFhmfRZdWrQ/UserByScreenName?variables=%7B%22screen_name%22%3A%22primus_labs%22%7D&features=%7B%22responsive_web_grok_bio_auto_translation_is_enabled%22%3Afalse%2C%22hidden_profile_subscriptions_enabled%22%3Atrue%2C%22payments_enabled%22%3Afalse%2C%22profile_label_improvements_pcf_label_in_post_enabled%22%3Atrue%2C%22rweb_tipjar_consumption_enabled%22%3Atrue%2C%22verified_phone_label_enabled%22%3Afalse%2C%22subscriptions_verification_info_is_identity_verified_enabled%22%3Atrue%2C%22subscriptions_verification_info_verified_since_enabled%22%3Atrue%2C%22highlights_tweets_tab_ui_enabled%22%3Atrue%2C%22responsive_web_twitter_article_notes_tab_enabled%22%3Atrue%2C%22subscriptions_feature_can_gift_premium%22%3Atrue%2C%22creator_subscriptions_tweet_preview_api_enabled%22%3Atrue%2C%22responsive_web_graphql_skip_user_profile_image_extensions_enabled%22%3Afalse%2C%22responsive_web_graphql_timeline_navigation_enabled%22%3Atrue%7D&fieldToggles=%7B%22withAuxiliaryUserLabels%22%3Atrue%7D",
            header: "",
            method: "GET",
            body: ""
        });

        bytes[] memory sigBytes = new bytes[](1);
        sigBytes[0] = bytes(
            "0xcdbf87ec6772ee6c734d3463b875792f5e49be43b38f76e3eeb498f4d757db34512c90c8eb78b1993d120286a4d5baa87e5a5fae01e194fe363381067e3e36981c"
        );

        att = Attestation({
            recipient: recipient,
            request: request,
            reponseResolve: response,
            data: "{\"screen_name\":\"wenjun_yuan1\"}",
            attConditions: "[{\"op\":\"STREQ\",\"field\":\"$.data.user.result.relationship_perspectives.following\",\"value\":\"true\"},{\"op\":\"STREQ\",\"field\":\"$.data.user.result.core.screen_name\",\"value\":\"primus_labs\"},{\"op\":\"REVEAL_STRING\",\"field\":\"$.screen_name\"}]",
            timestamp: 1740548090903,
            additionParams: "{\"algorithmType\":\"proxytls\",\"requests[1].url\":\"https://api.x.com/1.1/account/settings.json?include_ext_sharing_audiospaces_listening_data_with_followers=true&include_mention_filter=true&include_nsfw_user_flag=true&include_nsfw_admin_flag=true&include_ranked_timeline=true&include_alt_text_compose=true&ext=ssoConnections&include_country_code=true&include_ext_dm_nsfw_media_filter=true\",\"requests[1].method\":\"GET\",\"requests[1].body\":\"\",\"requests[1].header\":\"\",\"reponseResolves[1][0].keyName\":\"screen_name\",\"reponseResolves[1][0].parseType\":\"\",\"reponseResolves[1][0].parsePath\":\"$.screen_name\"}",
            attestors: attesters,
            signatures: sigBytes
        });
    }

    function test_NativeClaimToSmartAccount() public {
        NativePaymentReceiver receiver = new NativePaymentReceiver();
        bytes32 reId = _sendNativeEnvelope(tipper, 1 ether, 1, 1);
        Attestation memory att = _mockAttestationFor(address(receiver));

        vm.prank(address(receiver));
        primusRedEnvelope.reClaim(reId, att);

        assertEq(receiver.received(), 1 ether);
        assertEq(address(receiver).balance, 1 ether);
        assertEq(primusRedEnvelope.getClaimed(reId, "x&wenjun_yuan1"), true);
    }

    function test_NativeWithdrawToSmartAccount() public {
        NativePaymentReceiver receiver = new NativePaymentReceiver();
        bytes32 reId = _sendNativeEnvelope(address(receiver), 2 ether, 2, 1);

        // Advance beyond withdraw delay (30 days)
        vm.warp(block.timestamp + 31 days);

        vm.prank(address(receiver));
        primusRedEnvelope.reSenderWithdraw(reId);

        assertEq(receiver.received(), 2 ether);
        assertEq(address(receiver).balance, 3 ether);
    }

    function test_NativeRejectedClaimRestoresState() public {
        NativePaymentReceiver receiver = new NativePaymentReceiver();
        receiver.configure(true, address(0), ""); // Reject ETH transfer

        bytes32 reId = _sendNativeEnvelope(tipper, 1 ether, 1, 1);
        Attestation memory att = _mockAttestationFor(address(receiver));

        vm.prank(address(receiver));
        vm.expectRevert("Native transfer failed");
        primusRedEnvelope.reClaim(reId, att);

        assertEq(receiver.received(), 0);
        assertEq(primusRedEnvelope.getClaimed(reId, "x&wenjun_yuan1"), false);
    }

    function test_NativeReceiverCannotReenterReClaim() public {
        NativePaymentReceiver receiver = new NativePaymentReceiver();
        bytes32 reId = _sendNativeEnvelope(tipper, 2 ether, 2, 1);
        Attestation memory att = _mockAttestationFor(address(receiver));

        bytes memory reenterCall = abi.encodeWithSelector(primusRedEnvelope.reClaim.selector, reId, att);
        receiver.configure(false, address(primusRedEnvelope), reenterCall);

        vm.prank(address(receiver));
        primusRedEnvelope.reClaim(reId, att);

        assertEq(receiver.callbackSucceeded(), false);
        assertEq(receiver.received(), 1 ether);
    }
}
