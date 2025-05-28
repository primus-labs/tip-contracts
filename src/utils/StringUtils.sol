// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library StringUtils {
    /**
     * Compares two strings for equality.
     *
     * @param str1 The first string to compare.
     * @param str2 The second string to compare.
     * @return True if the strings are equal, false otherwise.
     */
    function equals(string memory str1, string memory str2) internal pure returns (bool) {
        return keccak256(abi.encodePacked(str1)) == keccak256(abi.encodePacked(str2));
    }

    function startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);
        if (prefixBytes.length > strBytes.length) {
            return false;
        }
        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (strBytes[i] != prefixBytes[i]) {
                return false;
            }
        }
        return true;
    }

    function addPrefix(string memory original, string memory prefix) internal pure returns (string memory) {
        return string(abi.encodePacked(prefix, original));
    }

    function suffixWith(string memory original, string memory suffix) internal pure returns (bool) {
        bytes memory originalBytes = bytes(original);
        bytes memory suffixBytes = bytes(suffix);
        uint256 suffixLength = suffixBytes.length;
        uint256 originalLength = originalBytes.length;

        if (suffixLength > originalLength) {
            return false;
        }

        for (uint i = 0; i < suffixLength; i++) {
            if (originalBytes[originalLength - suffixLength + i] != suffixBytes[i]) {
                return false;
            }
        }

        return true;
    }

    function extractStr(string memory original, bytes1 symbol) internal pure returns (string memory) {
        bytes memory urlBytes = bytes(original);
        uint256 queryStart = urlBytes.length;
        for (uint256 i = 0; i < urlBytes.length; i++) {
            if (urlBytes[i] == symbol) {
                queryStart = i;
                break;
            }
        }
        bytes memory baseUrlBytes = new bytes(queryStart);
        for (uint256 i = 0; i < queryStart; i++) {
            baseUrlBytes[i] = urlBytes[i];
        }
        return string(baseUrlBytes);
    }

    /**
     * Extract the base URL (ignoring query parameters)
     * @param url The full URL
     * @return The base URL without query parameters
     */
    function extractBaseUrl(string memory url) internal pure returns (string memory) {
        bytes memory urlBytes = bytes(url);
        uint256 queryStart = urlBytes.length;
        for (uint256 i = 0; i < urlBytes.length; i++) {
            if (urlBytes[i] == "?") {
                queryStart = i;
                break;
            }
        }
        bytes memory baseUrlBytes = new bytes(queryStart);
        for (uint256 i = 0; i < queryStart; i++) {
            baseUrlBytes[i] = urlBytes[i];
        }
        return string(baseUrlBytes);
    }
}
