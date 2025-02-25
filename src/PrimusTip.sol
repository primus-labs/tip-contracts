// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IPrimusZKTLS, Attestation } from "@primuslabs/zktls-contracts/src/IPrimusZKTLS.sol";
import {TipToken, TipRecipientInfo, TipRecipient, TipRecord} from "./types/Common.sol";
import "./utils/StringUtils.sol";
import "./utils/JsonParser.sol";

/**
 * @dev The Primus Tip contract is used to manage users’ tip funds.
 *      Tippers can lock funds in contracts, and recipients can claim the tip funds after verifying their identities.
 */
contract PrimusTip is OwnableUpgradeable {
    using StringUtils for string;
    using JsonParser for string;

    event TipEvent(string idSource, string id);
    event ClaimEvent(address indexed recipient, address tokenAddr, uint256 amount);

    mapping(string => mapping(string => TipRecord[])) private _tipRecords;
    // IPrimusZKTLS contract
    IPrimusZKTLS public primusZKTLS;
    // claim fee
    uint256 public claimFee;

    /**
     * @dev Initialize function to set the owner of the contract.
     *      This function is called during the contract deployment.
     * @param owner The contract owner.
     */
    function initialize(address owner, IPrimusZKTLS primusZKTLS_) public initializer {
        __Ownable_init(owner);
        primusZKTLS = primusZKTLS_;
    }

    /**
     * @dev Tipper tip the token to the recipient.
     *      Tipper can tip erc20, NFT and native token.
     *      Tipper tip the native token when the token.tokenName equals to native.
     * @param token The tip token.
     * @param recipient The recipient informations.
     */
    function tip(TipToken calldata token, TipRecipientInfo calldata recipient) external payable {
        require(token.tokenType.equals("erc20") || token.tokenType.equals("native"), "error token type");
        require(token.tokenAddress != address(0), "error token addr");
        require(recipient.amount > 0, "amount is zero");
        require(!recipient.id.equals(""), "id is empty");
        // TODO: check id source
        if (token.tokenType.equals("erc20")) {
            IERC20 tipToken = IERC20(token.tokenAddress);
            bool ret = tipToken.transferFrom(msg.sender, address(this), recipient.amount);
            require(ret, "transfer token fail");
        } else if (token.tokenType.equals("native")) {
            require(msg.value >= recipient.amount);
        }
        TipRecord memory tipRecord = TipRecord({
            tipRecipientInfo: recipient,
            tipToken: token,
            tipper: msg.sender,
            timestamp: block.timestamp
        });
        _tipRecords[recipient.idSource][recipient.id].push(tipRecord);
        emit TipEvent(recipient.idSource, recipient.id);
    }

    /**
     * @dev Tipper tip the token to the batch recipients.
     *      Tipper can tip erc20, NFT and native token.
     *      Tipper tip the native token when the token.tokenName equals to native.
     * @param token The tip token.
     * @param recipients The recipients informations.
     */
    function tipBatch(TipToken calldata token, TipRecipientInfo[] calldata recipients) external payable {
        require(token.tokenType.equals("erc20") || token.tokenType.equals("native"), "error token type");
        require(token.tokenAddress != address(0), "error token addr");
        // TODO: check id source
        uint256 totalAmount = 0;
        for (uint256 i = 0; i <= recipients.length; i++) {
            require(!recipients[i].id.equals(""), "one id is empty");
            totalAmount += recipients[i].amount;
        }
        require(totalAmount > 0, "amount is zero");
        if (token.tokenType.equals("erc20")) {
            IERC20 tipToken = IERC20(token.tokenAddress);
            bool ret = tipToken.transferFrom(msg.sender, address(this), totalAmount);
            require(ret, "transfer token fail");
        } else if (token.tokenType.equals("native")) {
            require(msg.value >= totalAmount);
        }

        for (uint256 i = 0; i <= recipients.length; i++) {
            TipRecord memory tipRecord = TipRecord({
                tipRecipientInfo: recipients[i],
                tipToken: token,
                tipper: msg.sender,
                timestamp: block.timestamp
            });
            _tipRecords[recipients[i].idSource][recipients[i].id].push(tipRecord);
            emit TipEvent(recipients[i].idSource, recipients[i].id);
        }
    }

    /**
     * @dev Recipient claims the tip tokens by the id source.
     */
    function claimBySource(string calldata idSource, Attestation calldata att) external payable {
        // TODO: check id source
        require(att.recipient != address(0), "to addr zero");
        primusZKTLS.verifyAttestation(att);
        // TODO: check the content of attestation
        string memory id = att.data.extractValue(att.reponseResolve[0].keyName);
        TipRecord[] memory tipRecords = _tipRecords[idSource][id];
        require(tipRecords.length > 0, "no claim token");
        delete _tipRecords[idSource][id];
        for (uint256 i = 0; i <= tipRecords.length; i++) {
            if (tipRecords[i].tipToken.tokenType.equals("erc20")) {
                IERC20 tipToken = IERC20(tipRecords[i].tipToken.tokenAddress);
                bool ret = tipToken.transfer(att.recipient, tipRecords[i].tipRecipientInfo.amount);
                require(ret, "claim token fail");
                emit ClaimEvent(att.recipient, tipRecords[i].tipToken.tokenAddress, tipRecords[i].tipRecipientInfo.amount);
            } else if (tipRecords[i].tipToken.tokenType.equals("native")) {
                (bool success, ) = att.recipient.call{value: tipRecords[i].tipRecipientInfo.amount}(new bytes(0));
                require(success, 'claim native fail');
                emit ClaimEvent(att.recipient, address(0), tipRecords[i].tipRecipientInfo.amount);
            }
            // TODO: compute fee
        }
    }

    /**
     * @dev Recipient claims the tip tokens by id sources.
     */
    function claimByMultiSource(string[] calldata idSources, Attestation[] calldata att) external payable {}

    /**
     * @dev The tipper withdraws tokens that have not been claimed within the specified time period.
     */
    function tipperWithdraw() external {}

    /**
     * @dev Get the tip tokens by id and id source of recipient.
     */
    function getTipRecords(TipRecipient calldata tipRecipient) external view returns (TipRecord[] memory) {
        return _tipRecords[tipRecipient.idSource][tipRecipient.id];
    }


    /**
     * @dev Add the id attestation source.
     */
    function addIdSource() external onlyOwner {}

    /**
     *  @dev set IPrimusZKTLS contract instance
     *  @param primusZKTLS_ The address of the IPrimusZKTLS contract
     */
    function setPrimusZKTLS(IPrimusZKTLS primusZKTLS_) public onlyOwner {
        primusZKTLS = primusZKTLS_;
    }

    /**
     *  @dev set claim fee
     *  @param claimFee_ The submission fee
     */
    function setClaimFee(uint256 claimFee_) public onlyOwner {
        claimFee = claimFee_;
    }
}
