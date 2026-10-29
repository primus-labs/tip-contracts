// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {Attestation} from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {PrimusTip} from "src/PrimusTip.sol";
import {TipToken, TipRecipientInfo, TipRecipient, TipRecord, TipWithdrawInfo} from "src/types/Common.sol";
import {StringUtils} from "src/utils/StringUtils.sol";
import {PrimusTestNFT} from "./PrimusTestNFT.sol";
import {TestUtils} from "./TestUtils.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {IPrimusZKTLS} from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";

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

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
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
    PrimusZKTLSMock public primusVerifier;
    address public owner = address(1);
    address public tipper = address(2);
    address public feeRecipient = address(0x456);
    address public user = address(0x789);
    address public recipientAddr = TestUtils.stringToAddress("0x7ab44DE0156925fe0c24482a2cDe48C465e47573");
    address public erc20Token = address(4);
    address public nftTokenAddr = address(5);

    function setUp() public {
        vm.startPrank(owner);
        primusVerifier = new PrimusZKTLSMock();
        primusTip = new PrimusTip();
        console.log("primusTip=", address(primusTip));
        primusTip.initialize(owner, primusVerifier, feeRecipient, 0);

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

        PrimusTestNFT nftToken = new PrimusTestNFT(owner);
        nftTokenAddr = address(nftToken);
        for (uint256 i = 0; i < 5; i++) {
            nftToken.safeMint(tipper, "uri");
        }
        vm.stopPrank();
    }

    function test_TipERC20() public {
        TipToken memory token = TipToken({tokenType: 0, tokenAddress: erc20Token});

        uint256[] memory nftIds = new uint256[](0);
        TipRecipientInfo memory recipientInfo =
            TipRecipientInfo({idSource: "tiktok", id: "user123", amount: 1000, nftIds: nftIds});

        vm.startPrank(tipper);
        IERC20(erc20Token).approve(address(primusTip), recipientInfo.amount);
        primusTip.tip(token, recipientInfo);
        vm.stopPrank();
    }

    function test_ClaimBySourceWithTiktok() public {
        string memory idSource = "tiktok";
        string memory id = "fksyuan";

        TipToken memory token = TipToken({tokenType: 1, tokenAddress: address(0)});
        uint256[] memory nftIds = new uint256[](0);
        TipRecipientInfo memory recipientInfo =
            TipRecipientInfo({idSource: idSource, id: id, amount: 1 ether, nftIds: nftIds});
        vm.deal(tipper, 10 ether);
        vm.startPrank(tipper);
        primusTip.tip{value: 1 ether}(token, recipientInfo);
        vm.stopPrank();

        assertEq(tipper.balance, 9 ether, "Native token transfer failed");
        assertEq(address(primusTip).balance, 1 ether, "Native token transfer failed");

        Attestation memory attestation;
        (attestation, idSource, id) = TestUtils._createTiktokAttestation();

        vm.startPrank(recipientAddr);
        primusTip.claimBySource(idSource, attestation);
        vm.stopPrank();
        console.log("recipientAddr.balance", recipientAddr.balance);
        assertEq(recipientAddr.balance, 1 ether, "Native token transfer failed");
    }

    function test_ClaimBySourceWithTiktok_Over_Expenses() public {
        string memory idSource = "tiktok";
        string memory id = "fksyuan";

        TipToken memory token = TipToken({tokenType: 1, tokenAddress: address(0)});
        uint256[] memory nftIds = new uint256[](0);
        TipRecipientInfo memory recipientInfo =
            TipRecipientInfo({idSource: idSource, id: id, amount: 2 ether, nftIds: nftIds});

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
        (attestation, idSource, id) = TestUtils._createTiktokAttestation();

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

        TipToken memory token = TipToken({tokenType: 1, tokenAddress: address(0)});
        uint256[] memory nftIds = new uint256[](0);
        TipRecipientInfo memory recipientInfo =
            TipRecipientInfo({idSource: idSource, id: id, amount: 1 ether, nftIds: nftIds});
        vm.deal(tipper, 10 ether);
        vm.startPrank(tipper);
        primusTip.tip{value: 1 ether}(token, recipientInfo);
        vm.stopPrank();
        Attestation memory attestation;
        (attestation, idSource, id) = TestUtils._createXAttestation();

        vm.startPrank(recipientAddr);
        primusTip.claimBySource(idSource, attestation);
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
        TipToken memory token = TipToken({tokenType: 0, tokenAddress: erc20Token});

        uint256[] memory nftIds = new uint256[](0);
        TipRecipientInfo memory recipientInfo =
            TipRecipientInfo({idSource: "tiktok", id: "user123", amount: 100, nftIds: nftIds});

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
        TipRecord memory tipRecord = primusTip.getTipRecords(TipRecipient({idSource: "tiktok", id: "user123"}))[0];

        TipWithdrawInfo memory recipient =
            TipWithdrawInfo({idSource: "tiktok", id: "user123", tipTimestamp: tipRecord.timestamp});
        recipients[0] = recipient;
        vm.startPrank(tipper);
        primusTip.tipperWithdraw(recipients);
        vm.stopPrank();

        assertEq(IERC20(erc20Token).balanceOf(tipper), initialBalance + 100, "Balance not updated correctly");
        assertEq(
            primusTip.getTipRecords(TipRecipient({idSource: "github", id: "user123"})).length, 0, "Records not cleared"
        );
    }

    function test_TipperWithdraw_MultipleRecords() public {
        for (uint256 i = 0; i < 5; i++) {
            string memory idStr = string(abi.encodePacked("user", TestUtils.uintToString(i)));
            TipRecipientInfo memory recipient =
                TipRecipientInfo({idSource: "github", id: idStr, amount: 100, nftIds: new uint256[](0)});
            vm.startPrank(tipper);
            IERC20(erc20Token).approve(address(primusTip), recipient.amount);
            uint256 tipperBalance = IERC20(erc20Token).balanceOf(tipper);
            console.log("tipperBalance:%d", tipperBalance);
            primusTip.tip(TipToken({tokenType: 0, tokenAddress: erc20Token}), recipient);
            vm.stopPrank();
        }

        assertEq(IERC20(erc20Token).balanceOf(tipper), 500, "Balance not updated correctly");

        vm.warp(block.timestamp + primusTip.withdrawDelay() + 1);

        //vm.prank(tipper);
        TipWithdrawInfo[] memory recipients = new TipWithdrawInfo[](5);
        TipRecord memory tipRecord = primusTip.getTipRecords(TipRecipient({idSource: "github", id: "user0"}))[0];

        TipWithdrawInfo memory recipient1 =
            TipWithdrawInfo({idSource: "github", id: "user0", tipTimestamp: tipRecord.timestamp});
        TipWithdrawInfo memory recipient2 =
            TipWithdrawInfo({idSource: "github", id: "user1", tipTimestamp: tipRecord.timestamp});
        TipWithdrawInfo memory recipient3 =
            TipWithdrawInfo({idSource: "github", id: "user2", tipTimestamp: tipRecord.timestamp});
        TipWithdrawInfo memory recipient4 =
            TipWithdrawInfo({idSource: "github", id: "user3", tipTimestamp: tipRecord.timestamp});
        TipWithdrawInfo memory recipient5 =
            TipWithdrawInfo({idSource: "github", id: "user4", tipTimestamp: tipRecord.timestamp});
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

        for (uint256 i = 0; i < 5; i++) {
            string memory idStr = string(abi.encodePacked("user", TestUtils.uintToString(i)));
            assertEq(primusTip.getTipRecords(TipRecipient({idSource: "github", id: idStr})).length, 0);
        }
    }

    function test_TipperWithdraw_MultipleRecords_2() public {
        for (uint256 i = 0; i < 25; i++) {
            string memory idStr = string(abi.encodePacked("user", TestUtils.uintToString(i)));
            TipRecipientInfo memory recipient =
                TipRecipientInfo({idSource: "github", id: idStr, amount: 1, nftIds: new uint256[](0)});
            vm.startPrank(tipper);
            IERC20(erc20Token).approve(address(primusTip), recipient.amount);
            uint256 tipperBalance = IERC20(erc20Token).balanceOf(tipper);
            console.log("tipperBalance:%d", tipperBalance);
            primusTip.tip(TipToken({tokenType: 0, tokenAddress: erc20Token}), recipient);
            vm.stopPrank();
        }

        assertEq(IERC20(erc20Token).balanceOf(tipper), 975, "Balance not updated correctly1");

        vm.warp(block.timestamp + primusTip.withdrawDelay() - 1 days);
        for (uint256 i = 25; i < 30; i++) {
            string memory idStr = string(abi.encodePacked("user", TestUtils.uintToString(i)));
            TipRecipientInfo memory recipient =
                TipRecipientInfo({idSource: "github", id: idStr, amount: 1, nftIds: new uint256[](0)});
            vm.startPrank(tipper);
            IERC20(erc20Token).approve(address(primusTip), recipient.amount);
            uint256 tipperBalance = IERC20(erc20Token).balanceOf(tipper);
            console.log("tipperBalance:%d", tipperBalance);
            primusTip.tip(TipToken({tokenType: 0, tokenAddress: erc20Token}), recipient);
            vm.stopPrank();
        }
        vm.stopPrank();

        vm.warp(block.timestamp + primusTip.withdrawDelay() + 2 days);

        // vm.prank(tipper);
        TipWithdrawInfo[] memory recipients = new TipWithdrawInfo[](5);
        TipRecord memory tipRecord = primusTip.getTipRecords(TipRecipient({idSource: "github", id: "user25"}))[0];

        TipWithdrawInfo memory recipient1 =
            TipWithdrawInfo({idSource: "github", id: "user25", tipTimestamp: tipRecord.timestamp});
        TipWithdrawInfo memory recipient2 =
            TipWithdrawInfo({idSource: "github", id: "user26", tipTimestamp: tipRecord.timestamp});
        TipWithdrawInfo memory recipient3 =
            TipWithdrawInfo({idSource: "github", id: "user27", tipTimestamp: tipRecord.timestamp});
        TipWithdrawInfo memory recipient4 =
            TipWithdrawInfo({idSource: "github", id: "user28", tipTimestamp: tipRecord.timestamp});
        TipWithdrawInfo memory recipient5 =
            TipWithdrawInfo({idSource: "github", id: "user29", tipTimestamp: tipRecord.timestamp});
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
        TipToken memory token = TipToken({tokenType: 0, tokenAddress: erc20Token});

        TipRecipientInfo memory expiredRecipient =
            TipRecipientInfo({idSource: "tiktok", id: "expired_user", amount: 200, nftIds: new uint256[](0)});

        TipRecipientInfo memory validRecipient =
            TipRecipientInfo({idSource: "tiktok", id: "valid_user", amount: 300, nftIds: new uint256[](0)});

        vm.startPrank(tipper);
        IERC20(erc20Token).approve(address(primusTip), expiredRecipient.amount + validRecipient.amount);
        primusTip.tip(token, expiredRecipient);

        vm.warp(block.timestamp + primusTip.withdrawDelay() - 1 days);
        primusTip.tip(token, validRecipient);
        vm.stopPrank();

        assertEq(
            primusTip.getTipRecords(TipRecipient({idSource: "tiktok", id: "expired_user"})).length,
            1,
            "Expired record not exist"
        );
        assertEq(
            primusTip.getTipRecords(TipRecipient({idSource: "tiktok", id: "valid_user"})).length,
            1,
            "Valid record not exist"
        );
        vm.warp(block.timestamp + 2 days);

        uint256 initialBalance = IERC20(erc20Token).balanceOf(tipper);

        TipWithdrawInfo[] memory recipients = new TipWithdrawInfo[](1);
        TipRecord memory tipRecord = primusTip.getTipRecords(TipRecipient({idSource: "tiktok", id: "expired_user"}))[0];
        TipWithdrawInfo memory recipient =
            TipWithdrawInfo({idSource: "tiktok", id: "expired_user", tipTimestamp: tipRecord.timestamp});
        recipients[0] = recipient;
        vm.prank(tipper);
        primusTip.tipperWithdraw(recipients);

        assertEq(IERC20(erc20Token).balanceOf(tipper), initialBalance + 200, "Expired amount not withdrawn");

        assertEq(
            primusTip.getTipRecords(TipRecipient({idSource: "tiktok", id: "expired_user"})).length,
            0,
            "Expired record not removed"
        );

        assertEq(
            primusTip.getTipRecords(TipRecipient({idSource: "tiktok", id: "valid_user"})).length,
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
        (attestations[0],,) = TestUtils._createTiktokAttestation();
        (attestations[1],,) = TestUtils._createXAttestation();

        _tipForSources(sources, 1 ether);

        vm.prank(recipientAddr);
        primusTip.claimByMultiSource{value: primusTip.claimFee() * 2}(sources, attestations);

        assertEq(recipientAddr.balance, 2 ether, "Should receive both tips");
    }

    function _tipForSources(string[] memory sources, uint256 amount) private {
        TipToken memory token = TipToken({tokenType: 1, tokenAddress: address(0)});

        for (uint256 i = 0; i < sources.length; i++) {
            string memory userName;
            if (sources[i].equals("tiktok")) {
                userName = "fksyuan";
            } else if (sources[i].equals("x")) {
                userName = "wenjun_yuan1";
            }

            TipRecipientInfo memory recipient =
                TipRecipientInfo({idSource: sources[i], id: userName, amount: amount, nftIds: new uint256[](0)});
            vm.deal(tipper, amount);
            vm.prank(tipper);
            primusTip.tip{value: amount}(token, recipient);
        }
    }

    // ========== tipBatch  ==========
    function test_TipBatch_Success() public {
        TipToken memory token = TipToken({tokenType: 0, tokenAddress: erc20Token});
        TipRecipientInfo[] memory recipients = new TipRecipientInfo[](2);
        recipients[0] = TipRecipientInfo({idSource: "github", id: "user1", amount: 50, nftIds: new uint256[](0)});
        recipients[1] = TipRecipientInfo({idSource: "github", id: "user2", amount: 50, nftIds: new uint256[](0)});

        vm.startPrank(tipper);
        IERC20(erc20Token).approve(address(primusTip), 100);
        primusTip.tipBatch(token, recipients);
        vm.stopPrank();

        assertEq(
            primusTip.getTipRecords(TipRecipient({idSource: "github", id: "user1"})).length, 1, "User1 record not found"
        );
        assertEq(
            primusTip.getTipRecords(TipRecipient({idSource: "github", id: "user2"})).length, 1, "User2 record not found"
        );
    }

    function test_TipBatch_100_Success() public {
        for (uint256 i = 0; i < 100; i++) {
            string memory idStr = string(abi.encodePacked("user", TestUtils.uintToString(i)));
            TipRecipientInfo memory recipient =
                TipRecipientInfo({idSource: "github", id: idStr, amount: 1, nftIds: new uint256[](0)});
            vm.startPrank(tipper);
            IERC20(erc20Token).approve(address(primusTip), recipient.amount);
            uint256 tipperBalance = IERC20(erc20Token).balanceOf(tipper);
            console.log("tipperBalance:%d", tipperBalance);
            primusTip.tip(TipToken({tokenType: 0, tokenAddress: erc20Token}), recipient);
            vm.stopPrank();
        }
    }

    function test_TipNFT() public {
        TipToken memory token = TipToken({tokenType: 2, tokenAddress: nftTokenAddr});

        uint256[] memory nftIds = new uint256[](1);
        nftIds[0] = 0;
        TipRecipientInfo memory recipientInfo =
            TipRecipientInfo({idSource: "tiktok", id: "user123", amount: 0, nftIds: nftIds});

        vm.startPrank(tipper);
        IERC721(nftTokenAddr).approve(address(primusTip), nftIds[0]);
        primusTip.tip(token, recipientInfo);
        vm.stopPrank();

        console.log(
            "test_TipNFT record=",
            primusTip.getTipRecords(TipRecipient({idSource: "tiktok", id: "user123"}))[0].nftIds[0]
        );
        assertEq(
            primusTip.getTipRecords(TipRecipient({idSource: "tiktok", id: "user123"}))[0].nftIds[0],
            0,
            "User record not found"
        );

        console.log("test_TipNFT owner=", IERC721(nftTokenAddr).ownerOf(0));
        assertEq(IERC721(nftTokenAddr).ownerOf(0), address(primusTip), "token owner incorrect");
    }

    function test_TipBatchNFT() public {
        TipToken memory token = TipToken({tokenType: 2, tokenAddress: nftTokenAddr});
        TipRecipientInfo[] memory recipientInfos = new TipRecipientInfo[](5);
        for (uint256 i = 0; i < 5; i++) {
            uint256[] memory nftIds = new uint256[](1);
            nftIds[0] = i;
            string memory idStr = string(abi.encodePacked("user", TestUtils.uintToString(i)));
            recipientInfos[i] = TipRecipientInfo({idSource: "tiktok", id: idStr, amount: 0, nftIds: nftIds});
        }

        vm.startPrank(tipper);
        IERC721(nftTokenAddr).setApprovalForAll(address(primusTip), true);
        primusTip.tipBatch(token, recipientInfos);
        vm.stopPrank();

        for (uint256 i = 0; i < 5; i++) {
            string memory idStr = string(abi.encodePacked("user", TestUtils.uintToString(i)));
            console.log(
                "test_TipNFT record=",
                primusTip.getTipRecords(TipRecipient({idSource: "tiktok", id: idStr}))[0].nftIds[0]
            );
            assertEq(
                primusTip.getTipRecords(TipRecipient({idSource: "tiktok", id: idStr}))[0].nftIds[0],
                i,
                "User record not found"
            );

            console.log("test_TipNFT owner=", IERC721(nftTokenAddr).ownerOf(i));
            assertEq(IERC721(nftTokenAddr).ownerOf(i), address(primusTip), "token owner incorrect");
        }
    }

    function test_TipBatch_Failure_ZeroAmount() public {
        TipToken memory token = TipToken({tokenType: 0, tokenAddress: erc20Token});
        TipRecipientInfo[] memory recipients = new TipRecipientInfo[](1);
        recipients[0] = TipRecipientInfo({idSource: "github", id: "user1", amount: 0, nftIds: new uint256[](0)});

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

        (string memory url, string memory jsonpath) = primusTip.idSourceCache("linkedin");

        assertEq(url, "https://linkedin.com", "LinkedIn source not added");
        assertEq(paths[0], jsonpath);

        (string memory url2, string memory jsonpath2) = primusTip.idSourceCache("facebook");
        assertEq(url2, "https://facebook.com", "Facebook source not added");
        assertEq(paths[1], jsonpath2);
    }
}
