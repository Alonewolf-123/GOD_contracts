// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./Ownable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract GOD is ERC20Upgradeable, Ownable {
    // a mapping from an address to whether or not it can mint / burn
    mapping(address => bool) controllers;

    // constructor() ERC20("GOD COIN", "GOD") { }
    function initialize() public virtual initializer {
        __ERC20_init("GOD COIN", "GOD");
    }

    /**
     * mints $GOD to a recipient
     * @param to the recipient of the $GOD
     * @param amount the amount of $GOD to mint
     */
    function mint(address to, uint256 amount) external {
        require(controllers[msg.sender], "Only controllers can mint");
        _mint(to, amount);
    }

    /**
     * burns $GOD from a holder
     * @param from the holder of the $GOD
     * @param amount the amount of $GOD to burn
     */
    function burn(address from, uint256 amount) external {
        require(controllers[msg.sender], "Only controllers can burn");
        _burn(from, amount);
    }

    /**
     * enables an address to mint / burn
     * @param controller the address to enable
     */
    function addController(address controller) external onlyOwner {
        controllers[controller] = true;
    }

    /**
     * disables an address from minting / burning
     * @param controller the address to disbale
     */
    function removeController(address controller) external onlyOwner {
        controllers[controller] = false;
    }
}
