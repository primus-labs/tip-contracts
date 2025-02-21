// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

struct TipToken {
    // Token Address.
    address tokenAddress;
    // Token Name.
    address tokenName;
}

struct TipRecipient {
    // The platform of the account.
    string idSource;
    // The unique identifier of the account.
    string id;
}
