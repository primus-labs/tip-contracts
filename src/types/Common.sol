// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

struct TipToken {
    // tokenType is erc20, nft or native. The native is native token.
    uint32 tokenType;
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
    // The amount of token when token is erc20 and native.
    uint256 amount;
    // The tip token.
    TipToken tipToken;
    // The tip timstamp.
    uint64 timestamp;
    // The tipper address.
    address tipper;
    // The nft token ids when token is nft.
    uint256[] nftIds;
}

struct IdSource {
    // The url of the source.
    string url;
    // The json path of the account.
    string jsonPath;
}