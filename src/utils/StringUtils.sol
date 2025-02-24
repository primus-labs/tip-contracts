// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library StringUtils {
    function equals(string memory str1, string memory str2) internal pure returns (bool) {
        return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
    }
}