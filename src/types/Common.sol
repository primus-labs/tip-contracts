// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

struct TipToken {
    // tokenType is erc20, nft or native. 0 means erc20, 1 means native and 2 means nft.
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

struct TipWithdrawInfo {
    // The platform of the account.
    string idSource;
    // The unique identifier of the account.
    string id;
    // The tip timstamp.
    uint64 tipTimestamp;
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

struct RESendParam {
    // Red envelope type, 0 means random red envelope, 1 means average red envelope.
    uint32 reType;
    // number indicates how many people the red envelope is sent to.
    uint32 number;
    // The total amount of the red envelope.
    uint256 amount;
    // A contract used to check whether you are eligible to receive a red envelope.
    address checkContract;
}

struct RERecord {
    // The red envelope id.
    bytes32 id;
    // The token type, tokenType is erc20 or native.
    uint32 tokenType;
    // Red envelope type, 0 means random red envelope, 1 means average red envelope.
    uint32 reType;
    // number indicates how many people the red envelope is sent to.
    uint32 number;
    // remainingNumber indicates how many people are left to receive the red envelope.
    uint32 remainingNumber;
    // Time when the red envelope was sent.
    uint64 timestamp;
    // Token Address.
    address tokenAddress;
    // The red envelope sender.
    address reSender;
    // A contract used to check whether you are eligible to receive a red envelope.
    address checkContract;
    // The total amount of the red envelope.
    uint256 amount;
    // The remaining amount of the red envelope.
    uint256 remainingAmount;
}