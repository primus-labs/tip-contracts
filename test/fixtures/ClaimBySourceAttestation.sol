// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {
    Attestation,
    AttNetworkRequest,
    AttNetworkResponseResolve,
    Attestor
} from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";

// Exact signed attestation supplied for the Base claim diagnostic.
library ClaimBySourceAttestation {
    function load() internal pure returns (Attestation memory att) {
        att.recipient = 0x6311c8a4F9CCa5a8FDFbc7a95FC565225d253c21;
        att.request = AttNetworkRequest(
            "https://api.x.com/1.1/account/settings.json?include_ext_sharing_audiospaces_listening_data_with_followers=true&include_mention_filter=true&include_nsfw_user_flag=true&include_nsfw_admin_flag=true&include_ranked_timeline=true&include_alt_text_compose=true&include_ext_dm_av_call_settings=true&ext=ssoConnections&include_country_code=true&include_ext_dm_nsfw_media_filter=true",
            "",
            "GET",
            ""
        );
        att.reponseResolve = new AttNetworkResponseResolve[](1);
        att.reponseResolve[0] = AttNetworkResponseResolve("", "", "$.screen_name");
        att.data = "{}";
        att.attConditions =
        "[{\"op\":\"STREQ\",\"field\":\"$.screen_name\",\"value\":\"daegu3071\",\"reveal_id\":null}]";
        att.additionParams =
            "{\"algorithmType\":\"proxytls\",\"claimTokenMap\":{\"ETH\":{\"symbol\":\"ETH\",\"image\":\"data:image/png;base64,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\",\"amount\":\"0.00401\",\"tokenType\":1}}}";
        att.timestamp = 1793198320005;
        att.attestors = new Attestor[](1);
        att.attestors[0] =
            Attestor(address(bytes20(hex"5ed3176045f68617b0958a61ac1868875c98c14d")), "https://primuslabs.xyz");
        att.signatures = new bytes[](1);
        att.signatures[0] =
            hex"3cfc1c31f41a8534371759e54e9c54a483afb8b947481157d93aedf861d0e0130ccd532004ae3f98ff02a25f9186d6c855966d7bb22c1e2f4c4d02ec125b34931c";
    }
}
