// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "src/PrimusFHETip.sol";
import "src/types/Common.sol";
import "src/utils/StringUtils.sol";
import "./TestUtils.sol";

import {
    Attestation as PrimusAttestation,
    AttNetworkRequest,
    AttNetworkResponseResolve,
    Attestor,
    IPrimusZKTLS
} from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";

import {Spf} from "@sunscreen/contracts/Spf.sol";
import {TfheThresholdDecryption} from "@sunscreen/contracts/TfheThresholdDecryption.sol";

/**
 * @title SpfMock
 *
 * A mock of the SPF functionality. It runs the plaintext equivalent of the logic
 * inside the `PrimusSpf` contract and keeps track of what the associated
 * ciphertext identifiers should contain. In testing, this contract is meant to be
 * called outside of the `PrimusFHETip` contract with the expected operations to
 * check that the operations in `PrimusFHETip` are correct.
 */
contract SpfMock {
    using Spf for *;
    using PrimusSpf for *;

    // This struct is used to store the decrypted value of a ciphertext and a
    // marker to indicate whether the value has been seen before (since mapping
    // contain default zero values).
    struct Value {
        bool seenBefore;
        uint256 value;
    }

    // This mapping is used to store the decrypted values of ciphertexts.
    mapping(bytes32 => Value) private _decryptedValue;

    constructor() {
        // Add in the trivial ciphertexts
        updateDecryptedValue(Spf.createTrivialZeroCiphertextParameter(64), 0);
        updateDecryptedValue(Spf.createTrivialOneCiphertextParameter(64), 1);
    }

    /**
     * Updates the decrypted value for a given parameter.
     *
     * @param param The SPF parameter containing the ciphertext identifier.
     * @param value The decrypted value to store.
     * @dev This function requires that the parameter's payload contains exactly one item,
     * which is the identifier for the ciphertext. It also checks that the value has not been
     * seen before to prevent overwriting previously decrypted values.
     */
    function updateDecryptedValue(Spf.SpfParameter memory param, uint256 value) internal {
        require(param.payload.length == 1, "updateDecryptedValue: empty payload");
        bytes32 identifier = param.payload[0];

        Value memory decrypted = _decryptedValue[identifier];

        require(!decrypted.seenBefore, "We are trying to update a value we have seen before");
        _decryptedValue[identifier] = Value(true, value);
    }

    /**
     * Retrieves the decrypted value for a given parameter.
     *
     * @param param The SPF parameter containing the ciphertext identifier.
     * @return The decrypted value associated with the identifier.
     * @dev This function requires that the parameter's payload contains exactly one item,
     *   which is the identifier for the ciphertext. It checks that the value has
     *   been seen * before to ensure it is valid. If the ciphertext has not been
     *   seen before, it reverts with an error.
     */
    function decryptedValue(Spf.SpfParameter memory param) internal view returns (uint256) {
        require(param.payload.length == 1, "decryptedValue: empty payload");
        bytes32 identifier = param.payload[0];

        Value memory decrypted = _decryptedValue[identifier];

        require(decrypted.seenBefore, "Mock decryption has not seen this value before");
        return decrypted.value;
    }

    /**
     * Decrypts a given SPF parameter. If the parameter is uninitialized, it
     * reverts with an error.
     *
     * @param value The SPF parameter to decrypt.
     * @return The decrypted value as a uint256.
     */
    function decrypt(Spf.SpfParameter memory value) public view returns (uint256) {
        if (Spf.isUninitializedParameter(value)) {
            revert("SpfMock.decrypt: Uninitialized parameter");
        }

        bytes32 identifier = value.payload[0];
        uint256 identifierNumber = uint256(identifier);

        // We are doing weird things here. Essentially we will assume that if
        // the number has mostly zeros that it is actually encoding a plaintext
        // number, where the underlying value is the encoded value.
        if (identifierNumber < type(uint128).max) {
            return identifierNumber;
        } else {
            // Otherwise look up the value in the mapping
            return decryptedValue(value);
        }
    }

    /**
     * Mocks the updateTip function from PrimusSpf. See that contract for
     * more details.
     *
     * @param amount The amount to tip (encrypted).
     * @param balance The current balance of the user (plaintext).
     * @param spent The current spent amount of the user (encrypted).
     * @return updatedAmount The updated amount after the tip (encrypted).
     * @return updatedSpent The updated spent amount after the tip (encrypted).
     */
    function updateTip(Spf.SpfParameter memory amount, uint256 balance, Spf.SpfParameter memory spent)
        public
        returns (Spf.SpfParameter memory, Spf.SpfParameter memory)
    {
        // Implement the plaintext logic
        uint256 amountValue = decrypt(amount);
        uint256 spentValue = decrypt(spent);

        if (amountValue + spentValue >= type(uint64).max) {
            amountValue = 0;
        }

        if (amountValue + spentValue > balance) {
            amountValue = 0;
        }

        uint256 updatedSpentValue = spentValue + amountValue;

        // Now mock call the SPF
        (Spf.SpfParameter memory updatedAmount, Spf.SpfParameter memory updatedSpent) =
            PrimusSpf.updateTip(amount, balance, spent);

        require(
            updatedAmount.payload.length == 1 && updatedSpent.payload.length == 1,
            "SpfMock.updateTip: Invalid output handles"
        );

        // Update our ciphertext storage
        updateDecryptedValue(updatedAmount, amountValue);
        updateDecryptedValue(updatedSpent, updatedSpentValue);

        return (updatedAmount, updatedSpent);
    }

    /**
     * Mocks the addToBalance function from PrimusSpf. See that contract for
     * more details.
     *
     * @param amount The amount to add to the balance (encrypted).
     * @param balance The current balance of the user (plaintext).
     * @return updatedBalance The updated balance after adding the amount (encrypted).
     */
    function addToBalance(Spf.SpfParameter memory amount, Spf.SpfParameter memory balance)
        public
        returns (Spf.SpfParameter memory)
    {
        // Implement the plaintext logic
        uint256 amountValue = decrypt(amount);
        uint256 balanceValue = decrypt(balance);

        if (amountValue + balanceValue >= type(uint64).max) {
            amountValue = 0;
        }

        uint256 updatedBalanceValue = balanceValue + amountValue;

        Spf.SpfParameter memory updatedBalance = PrimusSpf.addToBalance(amount, balance);

        require(updatedBalance.payload.length == 1, "SpfMock.simulateAddToBalance: Invalid output handle");

        updateDecryptedValue(updatedBalance, updatedBalanceValue);

        return updatedBalance;
    }

    /**
     * Mocks the withdraw function from PrimusSpf. See that contract for
     * more details.
     *
     * @param amountValue The amount to withdraw (plaintext).
     * @param balance The current balance of the user (encrypted).
     * @return updatedAmount The updated amount after the withdrawal (encrypted).
     * @return updatedBalance The updated balance after the withdrawal (encrypted).
     */
    function withdraw(uint256 amountValue, Spf.SpfParameter memory balance)
        public
        returns (Spf.SpfParameter memory, Spf.SpfParameter memory)
    {
        // Implement the plaintext logic
        uint256 balanceValue = decrypt(balance);
        uint256 updatedAmountValue = amountValue;

        if (amountValue > balanceValue) {
            updatedAmountValue = 0;
        }

        uint256 updatedBalanceValue = balanceValue - updatedAmountValue;

        (Spf.SpfParameter memory updatedAmount, Spf.SpfParameter memory updatedBalance) =
            PrimusSpf.withdraw(uint64(amountValue), balance);

        updateDecryptedValue(updatedAmount, updatedAmountValue);
        updateDecryptedValue(updatedBalance, updatedBalanceValue);

        return (updatedAmount, updatedBalance);
    }
}

contract ERC20Mock is IERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Default is 18, USDC and other fiat tokens are often 6.
    uint8 private _decimals;

    constructor(uint8 __decimals) {
        _decimals = __decimals;
    }

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

    function decimals() external view returns (uint8) {
        return _decimals;
    }
}

contract PrimusZKTLSMock is IPrimusZKTLS {
    function verifyAttestation(Attestation calldata) external pure override {
        return;
    }
}

contract PrimusFHETipTest is Test {
    using Currency for uint256;
    using StringUtils for string;

    PrimusFHETip public primusFHETip;
    PrimusZKTLSMock public primusZKTLS;
    SpfMock public spfMock;

    address public owner = address(1);
    address public tipper = address(2);
    address public feeRecipient = address(0x456);
    address public user = address(0x789);
    address public recipient = TestUtils.stringToAddress("0x7ab44DE0156925fe0c24482a2cDe48C465e47573");
    address public erc20Token = address(4);
    address public nftTokenAddr = address(5);
    address public threshold_decryption_service;

    uint256 constant STARTING_NATIVE_BALANCE = 10 ether;
    uint256 constant STARTING_ERC20_BALANCE = 1000;

    function setUp() public {
        vm.startPrank(owner);
        threshold_decryption_service = (new TfheThresholdDecryption()).THRESHOLD_DECRYPTION_SERVICE();
        primusZKTLS = new PrimusZKTLSMock();
        primusFHETip = new PrimusFHETip();
        spfMock = new SpfMock();
        console.log("primusFHETip=", address(primusFHETip));
        primusFHETip.initialize(owner, primusZKTLS, feeRecipient, 0, -1);

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

        primusFHETip.addBatchIdSource(sourceNames, urls, jsonPaths);

        ERC20Mock token = new ERC20Mock(18);
        erc20Token = address(token);
        token.mint(tipper, STARTING_ERC20_BALANCE);

        vm.deal(tipper, STARTING_NATIVE_BALANCE);
        vm.deal(recipient, STARTING_NATIVE_BALANCE);
        vm.deal(threshold_decryption_service, STARTING_NATIVE_BALANCE);

        vm.stopPrank();
    }

    function mockEncryption(uint256 value) internal pure returns (Spf.SpfParameter memory) {
        // Create a dummy ciphertext parameter for testing
        return Spf.createCiphertextParameter(Spf.SpfCiphertextIdentifier.wrap(bytes32(value)));
    }

    function nativeTipToken() public pure returns (TipToken memory) {
        return TipToken({tokenType: NATIVE_TYPE, tokenAddress: address(0)});
    }

    function erc20TipToken() public view returns (TipToken memory) {
        return TipToken({tokenType: ERC20_TYPE, tokenAddress: erc20Token});
    }

    ////////////////////////////////////////////////////////////////////////
    // Deposit and tip tests                                              //
    ////////////////////////////////////////////////////////////////////////

    function test_DepositERC20() public {
        TipToken memory token = erc20TipToken();
        uint256 amount = 1000;

        vm.startPrank(tipper);
        IERC20(erc20Token).approve(address(primusFHETip), amount);
        primusFHETip.deposit(token, amount);
        vm.stopPrank();

        assertEq(IERC20(erc20Token).balanceOf(tipper), 0);
        assertEq(IERC20(erc20Token).balanceOf(address(primusFHETip)), amount);
    }

    function test_TipERC20() public {
        TipToken memory token = erc20TipToken();

        EncryptedTipRecipientInfo memory recipientInfo =
            EncryptedTipRecipientInfo({idSource: "tiktok", id: "user123", amountId: mockEncryption(0)});

        vm.startPrank(tipper);
        primusFHETip.tip(token, recipientInfo);
        vm.stopPrank();
    }

    function test_depositAndTipERC20() public {
        TipToken memory token = erc20TipToken();

        uint256 amount = 1000;

        EncryptedTipRecipientInfo memory recipientInfo =
            EncryptedTipRecipientInfo({idSource: "tiktok", id: "user123", amountId: mockEncryption(0)});

        vm.startPrank(tipper);
        IERC20(erc20Token).approve(address(primusFHETip), amount);
        primusFHETip.depositAndTip(token, recipientInfo, amount);
        vm.stopPrank();

        assertEq(IERC20(erc20Token).balanceOf(tipper), STARTING_ERC20_BALANCE - amount);
        assertEq(IERC20(erc20Token).balanceOf(address(primusFHETip)), amount);
    }

    function test_DepositNative() public {
        TipToken memory token = nativeTipToken();
        uint256 amount = 1 ether;

        vm.startPrank(tipper);
        primusFHETip.deposit{value: amount}(token, amount);
        vm.stopPrank();

        assertEq(tipper.balance, STARTING_NATIVE_BALANCE - amount);
        assertEq(address(primusFHETip).balance, amount);
    }

    function test_TipNative() public {
        TipToken memory token = nativeTipToken();

        EncryptedTipRecipientInfo memory recipientInfo =
            EncryptedTipRecipientInfo({idSource: "tiktok", id: "user123", amountId: mockEncryption(0)});

        vm.startPrank(tipper);
        primusFHETip.tip(token, recipientInfo);
        vm.stopPrank();
    }

    function test_depositAndTipNative() public {
        TipToken memory token = nativeTipToken();

        uint256 amount = 1 ether;

        EncryptedTipRecipientInfo memory recipientInfo =
            EncryptedTipRecipientInfo({idSource: "tiktok", id: "user123", amountId: mockEncryption(0)});

        vm.startPrank(tipper);
        primusFHETip.depositAndTip{value: amount}(token, recipientInfo, amount);
        vm.stopPrank();

        assertEq(tipper.balance, STARTING_NATIVE_BALANCE - amount);
        assertEq(address(primusFHETip).balance, amount);
    }

    ////////////////////////////////////////////////////////////////////////
    // Claim tests                                                        //
    ////////////////////////////////////////////////////////////////////////

    // This is the main function we are using to test all variants of
    // claiming.
    function claimBySource(
        string memory idSource,
        string memory id,
        Attestation memory attestation,
        TipToken memory token,
        uint256 depositAmount,
        uint256 tipAmount
    ) public {
        uint256 normalizedTipAmount;
        uint256 normalizedDepositAmount;
        uint256 depositMsgValue;
        uint256 expectedTransferAmount = tipAmount;

        // If we underfund, we should expect no value is transferred
        if (depositAmount < tipAmount) {
            expectedTransferAmount = 0;
        }

        if (token.tokenType == NATIVE_TYPE) {
            normalizedTipAmount = tipAmount.weiToGwei();
            normalizedDepositAmount = depositAmount.weiToGwei();
            depositMsgValue = depositAmount;
            expectedTransferAmount = expectedTransferAmount.weiToGwei();
        } else {
            normalizedTipAmount = tipAmount;
            normalizedDepositAmount = depositAmount;
            depositMsgValue = 0;
        }

        Spf.SpfParameter memory amountId = mockEncryption(normalizedTipAmount);

        EncryptedTipRecipientInfo memory recipientInfo =
            EncryptedTipRecipientInfo({idSource: idSource, id: id, amountId: amountId});

        vm.startPrank(tipper);
        IERC20(erc20Token).approve(address(primusFHETip), depositAmount);
        primusFHETip.deposit{value: depositMsgValue}(token, depositAmount);
        primusFHETip.tip(token, recipientInfo);
        vm.stopPrank();

        // Simulate the tip
        spfMock.updateTip(amountId, normalizedDepositAmount, Spf.createTrivialZeroCiphertextParameter(64));
        Spf.SpfParameter memory tip = primusFHETip.getTipRecords(TipRecipient({idSource: idSource, id: id}))[0].amountId;
        uint256 decryptedTipAmount = spfMock.decrypt(tip);

        assertEq(decryptedTipAmount, expectedTransferAmount, "Tip amount mismatch");

        // Check that the user does have things to claim
        vm.startPrank(recipient);
        primusFHETip.claimBySource(idSource, attestation);
        vm.stopPrank();

        // Simulate claim
        spfMock.addToBalance(tip, Spf.createTrivialZeroCiphertextParameter(64));

        Spf.SpfParameter memory encryptedBalance = token.tokenType == NATIVE_TYPE
            ? primusFHETip.nativeClaimedBalanceOf(recipient)
            : primusFHETip.erc20ClaimedBalanceOf(recipient);

        uint256 decryptedBalance = spfMock.decrypt(encryptedBalance);
        assertEq(expectedTransferAmount, decryptedBalance);
    }

    // Test funding and token type variants ////////////////////////////////

    function test_ClaimBySourceTikTokNativeSufficientFunds() public {
        (Attestation memory attestation, string memory idSource, string memory id) =
            TestUtils._createTiktokAttestation();
        TipToken memory token = nativeTipToken();
        uint256 depositAmount = 1 ether;
        uint256 tipAmount = depositAmount;

        claimBySource(idSource, id, attestation, token, depositAmount, tipAmount);
    }

    function test_ClaimBySourceTikTokNativeInsufficientFunds() public {
        (Attestation memory attestation, string memory idSource, string memory id) =
            TestUtils._createTiktokAttestation();

        TipToken memory token = nativeTipToken();
        uint256 depositAmount = 0.5 ether;
        uint256 tipAmount = depositAmount * 2;

        claimBySource(idSource, id, attestation, token, depositAmount, tipAmount);
    }

    function test_ClaimBySourceTikTokERC20SufficientFunds() public {
        (Attestation memory attestation, string memory idSource, string memory id) =
            TestUtils._createTiktokAttestation();
        TipToken memory token = erc20TipToken();
        uint256 depositAmount = 100;
        uint256 tipAmount = depositAmount;

        claimBySource(idSource, id, attestation, token, depositAmount, tipAmount);
    }

    function test_ClaimBySourceTikTokERC20InsufficientFunds() public {
        (Attestation memory attestation, string memory idSource, string memory id) =
            TestUtils._createTiktokAttestation();
        TipToken memory token = erc20TipToken();
        uint256 depositAmount = 100;
        uint256 tipAmount = depositAmount * 2;

        claimBySource(idSource, id, attestation, token, depositAmount, tipAmount);
    }

    // Testing sources /////////////////////////////////////////////////////

    function test_ClaimBySourceXNativeSufficientFunds() public {
        (Attestation memory attestation, string memory idSource, string memory id) = TestUtils._createXAttestation();
        TipToken memory token = nativeTipToken();
        uint256 depositAmount = 1 ether;
        uint256 tipAmount = depositAmount;

        claimBySource(idSource, id, attestation, token, depositAmount, tipAmount);
    }

    ////////////////////////////////////////////////////////////////////////
    // Withdraw tests                                                     //
    ////////////////////////////////////////////////////////////////////////

    // This is the main function we are using to test all variants of
    // claiming.
    function withdraw(
        string memory idSource,
        string memory id,
        Attestation memory attestation,
        TipToken memory token,
        uint256 depositAmount,
        uint256 tipAmount,
        uint256 withdrawAmount
    ) public {
        uint256 gas = 100000 * 50 gwei; // Amount of gas to give the decryption oracle.

        uint256 normalizedTipAmount;
        uint256 normalizedDepositAmount;
        uint256 normalizedWithdrawAmount;
        uint256 normalizedExpectedWithdrawAmount;
        uint256 depositMsgValue;
        uint256 expectedTransferAmount = tipAmount;
        uint256 expectedWithdrawAmount = withdrawAmount;
        uint256 expectedGas = gas;

        // If we underfund, we should expect no value is transferred
        if (depositAmount < tipAmount) {
            expectedTransferAmount = 0;
            expectedWithdrawAmount = 0;
        }

        // If we pull out more, we expect to not have done a transfer.
        if (tipAmount < withdrawAmount) {
            expectedWithdrawAmount = 0;
        }

        if (token.tokenType == NATIVE_TYPE) {
            normalizedTipAmount = tipAmount.weiToGwei();
            normalizedDepositAmount = depositAmount.weiToGwei();
            normalizedWithdrawAmount = withdrawAmount.weiToGwei();
            normalizedExpectedWithdrawAmount = expectedWithdrawAmount.weiToGwei();
            depositMsgValue = depositAmount;
            expectedTransferAmount = expectedTransferAmount.weiToGwei();
        } else {
            normalizedTipAmount = tipAmount;
            normalizedDepositAmount = depositAmount;
            normalizedWithdrawAmount = withdrawAmount;
            normalizedExpectedWithdrawAmount = expectedWithdrawAmount;
            depositMsgValue = 0;
        }

        Spf.SpfParameter memory amountId = mockEncryption(normalizedTipAmount);

        EncryptedTipRecipientInfo memory recipientInfo =
            EncryptedTipRecipientInfo({idSource: idSource, id: id, amountId: amountId});

        vm.startPrank(tipper);
        IERC20(erc20Token).approve(address(primusFHETip), depositAmount);
        primusFHETip.deposit{value: depositMsgValue}(token, depositAmount);
        primusFHETip.tip(token, recipientInfo);
        vm.stopPrank();

        // Simulate the tip
        spfMock.updateTip(amountId, normalizedDepositAmount, Spf.createTrivialZeroCiphertextParameter(64));
        Spf.SpfParameter memory tip = primusFHETip.getTipRecords(TipRecipient({idSource: idSource, id: id}))[0].amountId;

        vm.startPrank(recipient);
        primusFHETip.claimBySource(idSource, attestation);
        vm.stopPrank();

        spfMock.addToBalance(tip, Spf.createTrivialZeroCiphertextParameter(64));

        Spf.SpfParameter memory balance = token.tokenType == ERC20_TYPE
            ? primusFHETip.erc20ClaimedBalanceOf(recipient)
            : primusFHETip.nativeClaimedBalanceOf(recipient);

        vm.startPrank(recipient);
        primusFHETip.withdraw{value: gas}(token, withdrawAmount);
        vm.stopPrank();

        (Spf.SpfParameter memory encryptedWithdrawAmount,) = spfMock.withdraw(uint64(normalizedWithdrawAmount), balance);

        uint256 decryptedWithdrawAmount = spfMock.decrypt(encryptedWithdrawAmount);
        assertEq(decryptedWithdrawAmount, normalizedExpectedWithdrawAmount, "Withdraw amount mismatch");

        vm.startPrank(threshold_decryption_service);
        primusFHETip.withdrawTokensCallback(
            Spf.passToDecryption(encryptedWithdrawAmount), normalizedExpectedWithdrawAmount
        );
        vm.stopPrank();

        if (token.tokenType == ERC20_TYPE) {
            assertEq(
                IERC20(erc20Token).balanceOf(tipper),
                STARTING_ERC20_BALANCE - depositAmount,
                "Tipper ERC20 balance incorrect"
            );
            assertEq(
                IERC20(erc20Token).balanceOf(address(primusFHETip)),
                depositAmount - expectedWithdrawAmount,
                "Tip contract ERC20 balance incorrect"
            );
            assertEq(
                IERC20(erc20Token).balanceOf(recipient), expectedWithdrawAmount, "Recipient ERC20 balance incorrect"
            );
            assertEq(recipient.balance, STARTING_NATIVE_BALANCE - expectedGas, "Recipient balance incorrect");
        } else {
            assertEq(tipper.balance, STARTING_NATIVE_BALANCE - depositAmount, "Tipper balance incorrect");
            assertEq(
                recipient.balance,
                STARTING_NATIVE_BALANCE + expectedWithdrawAmount - expectedGas,
                "Recipient balance incorrect"
            );
        }
    }

    // Test funding and token type variants ////////////////////////////////

    function test_WithdrawNativeSufficientFunds() public {
        (Attestation memory attestation, string memory idSource, string memory id) =
            TestUtils._createTiktokAttestation();
        TipToken memory token = nativeTipToken();
        uint256 depositAmount = 1 ether;
        uint256 tipAmount = depositAmount / 2;
        uint256 withdrawAmount = depositAmount / 4;

        withdraw(idSource, id, attestation, token, depositAmount, tipAmount, withdrawAmount);
    }

    function test_WithdrawNativeInsufficientFunds() public {
        (Attestation memory attestation, string memory idSource, string memory id) =
            TestUtils._createTiktokAttestation();
        TipToken memory token = nativeTipToken();
        uint256 depositAmount = 1 ether;
        uint256 tipAmount = depositAmount * 2;
        uint256 withdrawAmount = depositAmount / 4;

        withdraw(idSource, id, attestation, token, depositAmount, tipAmount, withdrawAmount);
    }

    function test_WithdrawNativeOverdrawn() public {
        (Attestation memory attestation, string memory idSource, string memory id) =
            TestUtils._createTiktokAttestation();
        TipToken memory token = nativeTipToken();
        uint256 depositAmount = 1 ether;
        uint256 tipAmount = depositAmount / 2;
        uint256 withdrawAmount = depositAmount * 4;

        withdraw(idSource, id, attestation, token, depositAmount, tipAmount, withdrawAmount);
    }

    function test_WithdrawERC20SufficientFunds() public {
        (Attestation memory attestation, string memory idSource, string memory id) =
            TestUtils._createTiktokAttestation();
        TipToken memory token = erc20TipToken();
        uint256 depositAmount = 100;
        uint256 tipAmount = depositAmount / 2;
        uint256 withdrawAmount = depositAmount / 4;

        withdraw(idSource, id, attestation, token, depositAmount, tipAmount, withdrawAmount);
    }

    function test_WithdrawERC20InsufficientFunds() public {
        (Attestation memory attestation, string memory idSource, string memory id) =
            TestUtils._createTiktokAttestation();
        TipToken memory token = erc20TipToken();
        uint256 depositAmount = 100;
        uint256 tipAmount = depositAmount * 2;
        uint256 withdrawAmount = depositAmount / 4;

        withdraw(idSource, id, attestation, token, depositAmount, tipAmount, withdrawAmount);
    }

    function test_WithdrawERC20Overdrawn() public {
        (Attestation memory attestation, string memory idSource, string memory id) =
            TestUtils._createTiktokAttestation();
        TipToken memory token = erc20TipToken();
        uint256 depositAmount = 100;
        uint256 tipAmount = depositAmount / 2;
        uint256 withdrawAmount = depositAmount * 4;

        withdraw(idSource, id, attestation, token, depositAmount, tipAmount, withdrawAmount);
    }

    ////////////////////////////////////////////////////////////////////////
    // Add batch id source tests                                          //
    ////////////////////////////////////////////////////////////////////////

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
        primusFHETip.addBatchIdSource(names, urls, paths);

        (string memory url, string memory jsonpath) = primusFHETip.idSourceCache("linkedin");

        assertEq(url, "https://linkedin.com", "LinkedIn source not added");
        assertEq(paths[0], jsonpath);

        (string memory url2, string memory jsonpath2) = primusFHETip.idSourceCache("facebook");
        assertEq(url2, "https://facebook.com", "Facebook source not added");
        assertEq(paths[1], jsonpath2);
    }

    function test_AddBatchIdSource_Failure_LengthMismatch() public {
        string[] memory names = new string[](2);
        string[] memory urls = new string[](1);

        vm.prank(owner);
        vm.expectRevert("length not match");
        primusFHETip.addBatchIdSource(names, urls, new string[](2));
    }
}
