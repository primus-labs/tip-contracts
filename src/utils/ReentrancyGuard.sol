// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library ReentrancyGuard {
    struct ReentrancyWrapper {
        bool locked;
    }

    modifier nonReentrant(ReentrancyWrapper storage guard) {
        require(!guard.locked, "ReentrancyGuard: reentrant call");
        guard.locked = true;
        _;
        guard.locked = false;
    }
}