// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

struct TipToken {
    // tokenType is erc20, nft or native. The native is native token.
    string tokenType;
    // Token Address.
    address tokenAddress;
}

struct TipRecipientInfo {
    // The platform of the account.
    string idSource;
    // The unique identifier of the account.
    string id;
    // The amount of token when token is erc20 and native.
    uint256 amount;
    // The nft token ids when token is nft.
    uint256[] nftIds;
}

struct TipRecipient {
    // The platform of the account.
    string idSource;
    // The unique identifier of the account.
    string id;
}

struct TipRecord {
    // The tip recipient info.
    TipRecipientInfo tipRecipientInfo;
    // The tip token.
    TipToken tipToken;
    // The tipper address.
    address tipper;
    // The tip timstamp.
    uint256 timestamp;
}
