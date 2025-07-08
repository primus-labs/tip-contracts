// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Currency {
    /**
     * @dev Converts an amount in wei to gwei.
     *
     * @param amount The amount in wei.
     * @return The equivalent amount in gwei.
     */
    function weiToGwei(uint256 amount) public pure returns (uint256) {
        return amount / 1e9;
    }

    /**
     * @dev Converts an amount in wei to gwei, ensuring the amount is a whole number of gwei.
     *
     * @param amount The amount in wei.
     * @return The equivalent amount in gwei.
     */
    function weiToGweiChecked(uint256 amount) public pure returns (uint256) {
        require(amount % 1e9 == 0, "Amount is not a whole number of Gwei");
        return amount / 1e9;
    }

    /**
     * Converts an amount in gwei to wei.
     *
     * @param amount The amount in gwei.
     * @return The equivalent amount in wei.
     */
    function gweiToWei(uint256 amount) public pure returns (uint256) {
        return amount * 1e9;
    }

    /**
     * Checks if an amount in wei is a whole number of gwei.
     *
     * @param amount The amount in wei.
     * @return True if the amount is a whole number of gwei, false otherwise.
     */
    function isWholeGwei(uint256 amount) public pure returns (bool) {
        return (amount % 1e9 == 0);
    }
}
