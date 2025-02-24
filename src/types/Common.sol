// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

struct TipToken {
    // tokenType is erc20, nft or native. The native is native token.
    string tokenType;
    // Token Address.
    address tokenAddress;
    // Token Name.
    address tokenName;
}

struct TipRecipientReq {
    // The platform of the account.
    string idSource;
    // The unique identifier of the account.
    string id;
    // The amount of token.
    uint256 amount;
}

struct TipRecipient {
    // The platform of the account.
    string idSource;
    // The unique identifier of the account.
    string id;
}
