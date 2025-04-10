// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/PrimusTip.sol";
import "src/types/Common.sol";
import "src/utils/StringUtils.sol";


import {
    Attestation as PrimusAttestation,
    AttNetworkRequest,
    AttNetworkResponseResolve,
    Attestor,
    IPrimusZKTLS
} from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";
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
contract PrimusTipTest is Test {
    using StringUtils for string;
    PrimusTip public primusTip;
    PrimusZKTLSMock public primusZKTLS;
    address public owner = address(1);
    address public tipper = address(2);
    address public feeRecipient = address(0x456);
    address public user = address(0x789);
    address public recipientAddr = stringToAddress("0x7ab44DE0156925fe0c24482a2cDe48C465e47573");
    address public erc20Token = address(4);
    
    function setUp() public {
        vm.startPrank(owner);
        primusZKTLS = new PrimusZKTLSMock();
        primusTip = new PrimusTip();
        primusTip.initialize(owner, primusZKTLS, feeRecipient, 0);

        string[] memory sourceNames = new string[](3);
        sourceNames[0] = "tiktok";
        sourceNames[1] = "x";
        sourceNames[2] = "github";
        string[] memory urls = new string[](3);
        urls[0] = "https://www.tiktok.com/passport/web/account/info/";
        urls[1] = "https://api.x.com/1.1/account/settings.json";
        urls[2] = "https://github.com";
        string[] memory jsonPaths = new string[](3);
        jsonPaths[0] = "$.data.username";
        jsonPaths[1] = "$.screen_name";
        jsonPaths[2] = "$.id";
        primusTip.addBatchIdSource(sourceNames, urls, jsonPaths);

        ERC20Mock token = new ERC20Mock();
        erc20Token = address(token);
        token.mint(tipper, 1000); 
        vm.stopPrank();
    }

    function test_TipERC20() public {
        TipToken memory token = TipToken({
            tokenType: 0,
            tokenAddress: erc20Token
        });

        uint256[] memory nftIds = new uint256[](0);
        TipRecipientInfo memory recipientInfo = TipRecipientInfo({
            idSource: "tiktok",
            id: "user123",
            amount: 1000,
            nftIds: nftIds 
        });

        vm.startPrank(tipper);
        IERC20(erc20Token).approve(address(primusTip), recipientInfo.amount);
        primusTip.tip(token, recipientInfo);
        vm.stopPrank();
    }

    function test_ClaimBySourceWithTiktok() public {
        string memory idSource = "tiktok";
        string memory id = "fksyuan";
        
        TipToken memory token = TipToken({
            tokenType: 1,
            tokenAddress: address(0)
        });
        uint256[] memory nftIds = new uint256[](0);
        TipRecipientInfo memory recipientInfo = TipRecipientInfo({
            idSource: idSource,
            id: id,
            amount: 1 ether,
            nftIds: nftIds
        });
        vm.deal(tipper, 10 ether);
        vm.startPrank(tipper);
        primusTip.tip{value: 1 ether}(token, recipientInfo);
        vm.stopPrank();

        assertEq(tipper.balance, 9 ether, "Native token transfer failed");
        assertEq(address(primusTip).balance, 1 ether, "Native token transfer failed");

        Attestation memory attestation;
        (attestation, idSource, id) = _createTiktokAttestation();

        vm.startPrank(recipientAddr);
        primusTip.claimBySource(idSource, attestation);
        vm.stopPrank();
        console.log("recipientAddr.balance", recipientAddr.balance);
        assertEq(recipientAddr.balance, 1 ether, "Native token transfer failed");
    }

     function test_ClaimBySourceWithTiktok_Over_Expenses() public {
        string memory idSource = "tiktok";
        string memory id = "fksyuan";
        
        TipToken memory token = TipToken({
            tokenType: 1,
            tokenAddress: address(0)
        });
        uint256[] memory nftIds = new uint256[](0);
        TipRecipientInfo memory recipientInfo = TipRecipientInfo({
            idSource: idSource,
            id: id,
            amount: 2 ether,
            nftIds: nftIds
        });

        vm.startPrank(owner);
        primusTip.setClaimFee(1 ether);
        vm.stopPrank();

        vm.deal(tipper, 20 ether);
        vm.startPrank(tipper);
        primusTip.tip{value: 3 ether}(token, recipientInfo);
        vm.stopPrank();

        assertEq(tipper.balance, 18 ether, "Native token transfer failed");
        assertEq(address(primusTip).balance, 2 ether, "Native token transfer failed");

        Attestation memory attestation;
        (attestation, idSource, id) = _createTiktokAttestation();

        vm.deal(recipientAddr, 5 ether);
        vm.startPrank(recipientAddr);
        primusTip.claimBySource{value: 2 ether}(idSource, attestation);
        vm.stopPrank();
        console.log("recipientAddr.balance", recipientAddr.balance);
        assertEq(recipientAddr.balance, 6 ether, "Native token transfer failed");
    }

    function test_ClaimBySourceWithX() public {
        string memory idSource = "x";
        string memory id = "wenjun_yuan1";
        
        TipToken memory token = TipToken({
            tokenType: 1,
            tokenAddress: address(0)
        });
        uint256[] memory nftIds = new uint256[](0);
        TipRecipientInfo memory recipientInfo = TipRecipientInfo({
            idSource: idSource,
            id: id,
            amount: 1 ether,
            nftIds: nftIds
        });
        vm.deal(tipper, 10 ether);
        vm.startPrank(tipper);
        primusTip.tip{value: 1 ether}(token, recipientInfo);
        vm.stopPrank();
        Attestation memory attestation;
        (attestation,idSource ,id) = _createXAttestation();
        
        vm.startPrank(recipientAddr);
        primusTip.claimBySource(idSource, attestation);
        vm.stopPrank();
        assertEq(recipientAddr.balance, 1 ether, "Native token transfer failed");
    }

    function test_ClaimBySourceAndTipIndex() public {
        string memory idSource = "x";
        string memory id = "wenjun_yuan1";

        TipToken memory token = TipToken({
            tokenType: 1,
            tokenAddress: address(0)
        });
        uint256[] memory nftIds = new uint256[](0);
        TipRecipientInfo memory recipientInfo = TipRecipientInfo({
            idSource: idSource,
            id: id,
            amount: 1 ether,
            nftIds: nftIds
        });
        vm.deal(tipper, 10 ether);
        vm.startPrank(tipper);
        primusTip.tip{value: 1 ether}(token, recipientInfo);
        vm.stopPrank();
        Attestation memory attestation;
        (attestation,idSource ,id) = _createXAttestation();

        vm.startPrank(recipientAddr);
        primusTip.claimBySourceAndTipIndex(idSource, attestation, 0);
        vm.stopPrank();
        assertEq(recipientAddr.balance, 1 ether, "Native token transfer failed");
    }


    function test_AddBatchIdSource_Failure_LengthMismatch() public {
        string[] memory names = new string[](2);
        string[] memory urls = new string[](1);
        
        vm.prank(owner);
        vm.expectRevert("length not match");
        primusTip.addBatchIdSource(names, urls, new string[](2));
    }


    // ========== tipperWithdraw ==========
    function test_TipperWithdraw_Success() public {
       TipToken memory token = TipToken({
            tokenType: 0,
            tokenAddress: erc20Token
        });

        uint256[] memory nftIds = new uint256[](0);
        TipRecipientInfo memory recipientInfo = TipRecipientInfo({
            idSource: "tiktok",
            id: "user123",
            amount: 100,
            nftIds: nftIds 
        });

        vm.startPrank(tipper);
        IERC20(erc20Token).approve(address(primusTip), recipientInfo.amount);
        primusTip.tip(token, recipientInfo);
        uint256 tipperBalance = IERC20(erc20Token).balanceOf(tipper);
        console.log("tipperBalance", tipperBalance);
        vm.stopPrank();

        vm.warp(block.timestamp + 31 days);
    
        uint256 initialBalance = IERC20(erc20Token).balanceOf(tipper);
        console.log("initialBalance", initialBalance);    
       
        TipWithdrawInfo[] memory recipients = new TipWithdrawInfo[](1);
        TipRecord memory tipRecord = primusTip.getTipRecords(TipRecipient("tiktok", "user123"))[0];

        TipWithdrawInfo memory recipient = TipWithdrawInfo("tiktok", "user123", tipRecord.timestamp);
        recipients[0] = recipient;
        vm.startPrank(tipper);
        primusTip.tipperWithdraw(recipients);
        vm.stopPrank();

        assertEq(
            IERC20(erc20Token).balanceOf(tipper),
            initialBalance + 100,
            "Balance not updated correctly"
        );
        assertEq(
            primusTip.getTipRecords(TipRecipient("github", "user123")).length,
            0,
            "Records not cleared"
        );
    }

    function test_TipperWithdraw_MultipleRecords() public {
        for (uint i = 0; i < 5; i++) {
            string memory idStr = string(abi.encodePacked("user", uintToString(i)));
            TipRecipientInfo memory recipient = TipRecipientInfo(
                "github", 
                idStr,
                100,
                new uint256[](0)
            );
            vm.startPrank(tipper);
            IERC20(erc20Token).approve(address(primusTip), recipient.amount);
            uint256 tipperBalance = IERC20(erc20Token).balanceOf(tipper);
            console.log("tipperBalance:%d", tipperBalance);
            primusTip.tip(TipToken(0, erc20Token), recipient);
            vm.stopPrank();
        }

        assertEq(IERC20(erc20Token).balanceOf(tipper), 500, "Balance not updated correctly");

        vm.warp(block.timestamp + primusTip.withdrawDelay() + 1);
        
        
        //vm.prank(tipper);
        TipWithdrawInfo[] memory recipients = new TipWithdrawInfo[](5);
        TipRecord memory tipRecord = primusTip.getTipRecords(TipRecipient("github", "user0"))[0];

        TipWithdrawInfo memory recipient1 = TipWithdrawInfo("github", "user0", tipRecord.timestamp);
        TipWithdrawInfo memory recipient2 = TipWithdrawInfo("github", "user1", tipRecord.timestamp);
        TipWithdrawInfo memory recipient3 = TipWithdrawInfo("github", "user2", tipRecord.timestamp);
        TipWithdrawInfo memory recipient4 = TipWithdrawInfo("github", "user3", tipRecord.timestamp);
        TipWithdrawInfo memory recipient5 = TipWithdrawInfo("github", "user4", tipRecord.timestamp);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        recipients[2] = recipient3;
        recipients[3] = recipient4;
        recipients[4] = recipient5;

        vm.startPrank(tipper);
        assertEq(IERC20(erc20Token).balanceOf(tipper), 500, "Balance not updated correctly");
        primusTip.tipperWithdraw(recipients);
        vm.stopPrank();

        assertEq(IERC20(erc20Token).balanceOf(tipper), 1000, "Balance not updated correctly");

        for (uint i = 0; i < 5; i++) {
            string memory idStr = string(abi.encodePacked("user", uintToString(i)));
            assertEq(primusTip.getTipRecords(TipRecipient("github", idStr)).length, 0);
        }
    }

    function test_TipperWithdraw_MultipleRecords_2() public {
        for (uint i = 0; i < 25; i++) {
            string memory idStr = string(abi.encodePacked("user", uintToString(i)));
            TipRecipientInfo memory recipient = TipRecipientInfo(
                "github", 
                idStr,
                1,
                new uint256[](0)
            );
            vm.startPrank(tipper);
            IERC20(erc20Token).approve(address(primusTip), recipient.amount);
            uint256 tipperBalance = IERC20(erc20Token).balanceOf(tipper);
            console.log("tipperBalance:%d", tipperBalance);
            primusTip.tip(TipToken(0, erc20Token), recipient);
            vm.stopPrank();
        }

        assertEq(IERC20(erc20Token).balanceOf(tipper), 975, "Balance not updated correctly1");

        vm.warp(block.timestamp + primusTip.withdrawDelay() - 1 days); 
         for (uint i = 25; i < 30; i++) {
            string memory idStr = string(abi.encodePacked("user", uintToString(i)));
            TipRecipientInfo memory recipient = TipRecipientInfo(
                "github", 
                idStr,
                1,
                new uint256[](0)
            );
            vm.startPrank(tipper);
            IERC20(erc20Token).approve(address(primusTip), recipient.amount);
            uint256 tipperBalance = IERC20(erc20Token).balanceOf(tipper);
            console.log("tipperBalance:%d", tipperBalance);
            primusTip.tip(TipToken(0, erc20Token), recipient);
            vm.stopPrank();
        }
        vm.stopPrank();
        

        vm.warp(block.timestamp + primusTip.withdrawDelay() + 2 days);
        
        // vm.prank(tipper);
        TipWithdrawInfo[] memory recipients = new TipWithdrawInfo[](5);
        TipRecord memory tipRecord = primusTip.getTipRecords(TipRecipient("github", "user25"))[0];

        TipWithdrawInfo memory recipient1 = TipWithdrawInfo("github", "user25", tipRecord.timestamp);
        TipWithdrawInfo memory recipient2 = TipWithdrawInfo("github", "user26", tipRecord.timestamp);
        TipWithdrawInfo memory recipient3 = TipWithdrawInfo("github", "user27", tipRecord.timestamp);
        TipWithdrawInfo memory recipient4 = TipWithdrawInfo("github", "user28", tipRecord.timestamp);
        TipWithdrawInfo memory recipient5 = TipWithdrawInfo("github", "user29", tipRecord.timestamp);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        recipients[2] = recipient3;
        recipients[3] = recipient4;
        recipients[4] = recipient5;

        vm.startPrank(tipper);
        assertEq(IERC20(erc20Token).balanceOf(tipper), 970, "Balance not updated correctly2");
        primusTip.tipperWithdraw(recipients);
        vm.stopPrank();

        assertEq(IERC20(erc20Token).balanceOf(tipper), 975, "Balance not updated correctly3");

    }
    
    function test_TipperWithdraw_PartiallyExpired() public {
        TipToken memory token = TipToken(0, erc20Token);
    
        TipRecipientInfo memory expiredRecipient = TipRecipientInfo(
            "tiktok", 
            "expired_user",
            200,
            new uint256[](0)
        );
    
        TipRecipientInfo memory validRecipient = TipRecipientInfo(
            "tiktok", 
            "valid_user",
            300,
            new uint256[](0)
        );

        vm.startPrank(tipper);
        IERC20(erc20Token).approve(address(primusTip), expiredRecipient.amount + validRecipient.amount);
        primusTip.tip(token, expiredRecipient);
    
  
        vm.warp(block.timestamp + primusTip.withdrawDelay() - 1 days); 
        primusTip.tip(token, validRecipient); 
        vm.stopPrank();


        assertEq(
            primusTip.getTipRecords(TipRecipient("tiktok", "expired_user")).length,
            1,
            "Expired record not exist"
        );
        assertEq(
            primusTip.getTipRecords(TipRecipient("tiktok", "valid_user")).length,
            1,
            "Valid record not exist"
        );
        vm.warp(block.timestamp + 2 days);

        uint256 initialBalance = IERC20(erc20Token).balanceOf(tipper);
    
        TipWithdrawInfo[] memory recipients = new TipWithdrawInfo[](1);
        TipRecord memory tipRecord = primusTip.getTipRecords(TipRecipient("tiktok", "expired_user"))[0];
        TipWithdrawInfo memory recipient = TipWithdrawInfo("tiktok", "expired_user", tipRecord.timestamp);
        recipients[0] = recipient;
        vm.prank(tipper);
        primusTip.tipperWithdraw(recipients);

        assertEq(
            IERC20(erc20Token).balanceOf(tipper),
            initialBalance + 200, 
            "Expired amount not withdrawn"
        );
    
        assertEq(
            primusTip.getTipRecords(TipRecipient("tiktok", "expired_user")).length,
            0,
            "Expired record not removed"
        );
    
        assertEq(
            primusTip.getTipRecords(TipRecipient("tiktok", "valid_user")).length,
            1,
            "Valid record incorrectly removed"
        );
    
    }

    // ========== claimByMultiSource  ==========
    function test_ClaimByMultiSource_Success() public {
        string[] memory sources = new string[](2);
        sources[0] = "tiktok";
        sources[1] = "x";
    
        Attestation[] memory attestations = new Attestation[](2);
        (attestations[0], , ) = _createTiktokAttestation();
        (attestations[1], , ) = _createXAttestation();

        _tipForSources(sources, 1 ether);

        
        vm.prank(recipientAddr);
        primusTip.claimByMultiSource{value: primusTip.claimFee() * 2}(sources, attestations);

        assertEq(recipientAddr.balance, 2 ether, "Should receive both tips");
    }

    function _tipForSources(string[] memory sources, uint256 amount) private {
        TipToken memory token = TipToken(1, address(0));
    
        for (uint i = 0; i < sources.length; i++) {
            string memory userName ;
            if (sources[i].equals("tiktok")){
                userName = "fksyuan";
            }else if (sources[i].equals("x")){
                userName = "wenjun_yuan1";
            }

            TipRecipientInfo memory recipient = TipRecipientInfo(
                sources[i],
                userName,
                amount,
                new uint256[](0)
            );
            vm.deal(tipper, amount);
            vm.prank(tipper);
            primusTip.tip{value: amount}(token, recipient);
        }
    }

    // ========== tipBatch  ==========
    function test_TipBatch_Success() public {
        TipToken memory token = TipToken(0, erc20Token);
        TipRecipientInfo[] memory recipients = new TipRecipientInfo[](2);
        recipients[0] = TipRecipientInfo("github", "user1", 50, new uint256[](0));
        recipients[1] = TipRecipientInfo("github", "user2", 50, new uint256[](0));

        vm.startPrank(tipper);
        IERC20(erc20Token).approve(address(primusTip), 100);
        primusTip.tipBatch(token, recipients);
        vm.stopPrank();

        assertEq(
            primusTip.getTipRecords(TipRecipient("github", "user1")).length,
            1,
            "User1 record not found"
        );
        assertEq(
            primusTip.getTipRecords(TipRecipient("github", "user2")).length,
            1,
            "User2 record not found"
        );
    }

     function test_TipBatch_100_Success() public {
         for (uint i = 0; i < 100; i++) {
            string memory idStr = string(abi.encodePacked("user", uintToString(i)));
            TipRecipientInfo memory recipient = TipRecipientInfo(
                "github", 
                idStr,
                1,
                new uint256[](0)
            );
            vm.startPrank(tipper);
            IERC20(erc20Token).approve(address(primusTip), recipient.amount);
            uint256 tipperBalance = IERC20(erc20Token).balanceOf(tipper);
            console.log("tipperBalance:%d", tipperBalance);
            primusTip.tip(TipToken(0, erc20Token), recipient);
            vm.stopPrank();
        }
    }


    function test_TipBatch_Failure_ZeroAmount() public {
        TipToken memory token = TipToken(0, erc20Token);
        TipRecipientInfo[] memory recipients = new TipRecipientInfo[](1);
        recipients[0] = TipRecipientInfo("github", "user1", 0, new uint256[](0));

        vm.startPrank(tipper);
        vm.expectRevert("amount is zero");
        primusTip.tipBatch(token, recipients);
        vm.stopPrank();
    }

    // ========== addBatchIdSource  ==========
    function test_AddBatchIdSource_Success() public {
        string[] memory names = new string[](2);
        names[0] = "linkedin";
        names[1] = "facebook";
    
        string[] memory urls = new string[](2);
        urls[0] = "https://linkedin.com";
        urls[1] = "https://facebook.com";
    
        string[] memory paths = new string[](2);
        paths[0] = "$.profile";
        paths[1] = "$.user";

        vm.prank(owner);
        primusTip.addBatchIdSource(names, urls, paths);

        (string memory url,string memory jsonpath) = primusTip.idSourceCache("linkedin");

        assertEq(
            url,
            "https://linkedin.com",
            "LinkedIn source not added"
        );
        assertEq(paths[0], jsonpath);
        
        (string memory url2,string memory jsonpath2) = primusTip.idSourceCache("facebook");
        assertEq(
            url2,
            "https://facebook.com",
            "Facebook source not added"
        );
        assertEq(paths[1], jsonpath2);
    }

    function _createTiktokAttestation() private pure returns (
        Attestation memory att,
        string memory idSource,
        string memory id
    ) {
            idSource = "tiktok";
            id = "fksyuan";
            address receiptAddr = stringToAddress("0x7ab44DE0156925fe0c24482a2cDe48C465e47573");
            AttNetworkResponseResolve[] memory response = new AttNetworkResponseResolve[](1);
            response[0] = AttNetworkResponseResolve({
                keyName: "username",
                parseType: "jsonpath",
                parsePath: "$.data.username"
            });

            Attestor[] memory attesters = new Attestor[](1);
            address addr = stringToAddress("0xdb736b13e2f522dbe18b2015d0291e4b193d8ef6");
            attesters[0] = Attestor({
                attestorAddr:addr,
                url:"https://primuslabs.xyz"
            });

            AttNetworkRequest memory request = AttNetworkRequest({
                url: "https://www.tiktok.com/passport/web/account/info/?WebIdLastTime=1733992482&aid=1459&app_language=en&app_name=tiktok_web&browser_language=en-GB-oxendict&browser_name=Mozilla&browser_online=true&browser_platform=MacIntel&browser_version=5.0%20%28Macintosh%3B%20Intel%20Mac%20OS%20X%2010_15_7%29%20AppleWebKit%2F537.36%20%28KHTML%2C%20like%20Gecko%29%20Chrome%2F132.0.0.0%20Safari%2F537.36&channel=tiktok_web&cookie_enabled=true&data_collection_enabled=true&device_id=7447440952928912914&device_platform=web_pc&focus_state=true&from_page=video&history_len=2&is_fullscreen=false&is_page_visible=true&odinId=7316364920953930757&os=mac&priority_region=&referer=&region=JP&screen_height=900&screen_width=1440&tz_name=Asia%2FShanghai&user_is_login=true&webcast_language=en&msToken=NrdkcVqela5VoeEu_UTmbqWImsHXs7pH4lznkqUTAYmGUDIfkVuAKidYtPPT4uurs6E5zEr6hgH4PIiSGmwHAdasjzqU_t32i11t6ttzYXu6vnGLARFHvih4HpaFiypvxeMVOHUgEdozqExEnZGwbKCkBHI=&X-Bogus=DFSzswVOF9TANyy3tDY4pfLNKBPp&_signature=_02B4Z6wo00001Oq9JxQAAIDDuEIHDW9Ft8zqvSOAAF0X59",
                header: "",
                method: "GET",
                body: ""
            });

            bytes[] memory sigBytes = new bytes[](1);
            sigBytes[0] = bytes("0x864997e50534f11042e2e8ad177d7d0bc9bbf49e050f04e89cf88071e2c2e3821dab1df547307881cc5572c5f2981e9545b2d861685844d63bf703f5381bfc201b");
            att = Attestation({
                recipient: receiptAddr,
                request: request,
                reponseResolve: response,
                data: "",
                attConditions: "[{\"op\":\"STREQ\",\"field\":\"$.data.username\",\"value\":\"fksyuan\"}]",
                timestamp:1740554854743,
                additionParams:"{\"algorithmType\":\"proxytls\"}",
                attestors: attesters,
                signatures: sigBytes
            });
        
            return (att,"tiktok","fksyuan");
    }

    function _createXAttestation() private pure returns
    (
        Attestation memory att,
        string memory idSource,
        string memory id
    ) {
        idSource = "x";
        id = "wenjun_yuan1";
        address receiptAddr = stringToAddress("0x7ab44DE0156925fe0c24482a2cDe48C465e47573");
        AttNetworkResponseResolve[] memory response = new AttNetworkResponseResolve[](1);
            response[0] = AttNetworkResponseResolve({
                keyName: "screen_name",
                parseType: "jsonpath",
                parsePath: "$.screen_name"
            });

        Attestor[] memory attesters = new Attestor[](1);
        address addr = stringToAddress("0xdb736b13e2f522dbe18b2015d0291e4b193d8ef6");
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
        sigBytes[0] = bytes("0xe0617d7d4b6f016aa68bed6d6afc8e1f28e3a2bf5ab53bd7822ceef9bef388b94f27097a1b3db5a451d3f7e3647e9f847c94e9de266b9194692a8e87519af8a01b");
        att = Attestation({
            recipient: receiptAddr,
            request: request,
            reponseResolve: response,
            data: "",
            attConditions: "[{\"op\":\"STREQ\",\"field\":\"$.screen_name\",\"value\":\"wenjun_yuan1\"}]",
            timestamp:1740548090903,
            additionParams:"{\"algorithmType\":\"proxytls\"}",
            attestors: attesters,
            signatures: sigBytes
        });
        return (att, idSource, id);
    }


    function _createInvalidAttestation() private pure returns (
        Attestation memory att,
        string memory idSource,
        string memory id
    ) {
        idSource = "github";
        id = "invalid_user";
         AttNetworkResponseResolve[] memory response = new AttNetworkResponseResolve[](1);
            response[0] = AttNetworkResponseResolve({
                keyName: "screen_name",
                parseType: "",
                parsePath: "$.screen_name"
            });

        Attestor[] memory attesters = new Attestor[](1);
        address addr = stringToAddress("0xdb736b13e2f522dbe18b2015d0291e4b193d8ef6");
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
        sigBytes[0] = bytes("0xe0617d7d4b6f016aa68bed6d6afc8e1f28e3a2bf5ab53bd7822ceef9bef388b94f27097a1b3db5a451d3f7e3647e9f847c94e9de266b9194692a8e87519af8a01b");
        att = Attestation({
            recipient: address(0),
            request: request,
            reponseResolve: response,
            data: "{\"screen_name\":\"wenjun_yuan1\"}", 
            attConditions: "[{\"op\":\"REVEAL_STRING\",\"field\":\"$.screen_name\"}]",
            timestamp:1740548090903,
            additionParams:"{\"algorithmType\":\"proxytls\"}",
            attestors: attesters,
            signatures: sigBytes
        });
        return (att, idSource, id);
    }


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
