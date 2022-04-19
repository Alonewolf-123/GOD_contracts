// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IGOD {
    /**
     * @dev burns $GOD from a holder
     * @param from the holder of the $GOD
     * @param amount the amount of $GOD to burn
     */
    function burn(address from, uint256 amount) external;

    /**
     * @dev mints $GOD to a recipient
     * @param to the recipient of the $GOD
     * @param amount the amount of $GOD to mint
     */
    function mint(address to, uint256 amount) external;
}
