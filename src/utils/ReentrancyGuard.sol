// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

library ReentrancyGuard {
    struct ReentrancyWrapper {
        bool locked;
    }

    function nonReentrant(ReentrancyWrapper storage wrapper) internal {
        require(!wrapper.locked, "ReentrancyGuard: reentrant call");
        wrapper.locked = true;
    }

    function unlock(ReentrancyWrapper storage wrapper) internal {
        wrapper.locked = false;
    }
}