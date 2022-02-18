// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title GOD token
/// @author Bounyavong
/// @dev basic token of the GameOfDwarfs
contract GOD is ERC20Upgradeable, OwnableUpgradeable {
    // a mapping from an address to whether or not it can mint / burn
    mapping(address => bool) controllers;

    /**
     * @dev initialize the ERC20 and set the token name & symbol
     */
    function initialize() public virtual initializer {
        __ERC20_init("GOD COIN", "GOD");
    }

    /**
     * @dev mints $GOD to a recipient
     * @param to the recipient of the $GOD
     * @param amount the amount of $GOD to mint
     */
    function mint(address to, uint256 amount) external {
        require(controllers[msg.sender], "Only controllers can mint");
        _mint(to, amount);
    }

    /**
     * @dev burns $GOD from a holder
     * @param from the holder of the $GOD
     * @param amount the amount of $GOD to burn
     */
    function burn(address from, uint256 amount) external {
        require(controllers[msg.sender], "Only controllers can burn");
        _burn(from, amount);
    }

    /**
     * @dev enables an address to mint / burn
     * @param controller the address to enable
     */
    function addController(address controller) external onlyOwner {
        controllers[controller] = true;
    }

    /**
     * @dev disables an address from minting / burning
     * @param controller the address to disbale
     */
    function removeController(address controller) external onlyOwner {
        controllers[controller] = false;
    }
}
