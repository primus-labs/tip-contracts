// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library StringUtils {
    function equals(string memory str1, string memory str2) internal pure returns (bool) {
        return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
    }

    function startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);
        if (prefixBytes.length > strBytes.length) {
            return false;
        }
        for (uint i = 0; i < prefixBytes.length; i++) {
            if (strBytes[i] != prefixBytes[i]) {
                return false;
            }
        }
        return true;
    }

    function addPrefix(string memory original, string memory prefix) internal pure returns (string memory) {
        return string(abi.encodePacked(prefix, original));
    }
}