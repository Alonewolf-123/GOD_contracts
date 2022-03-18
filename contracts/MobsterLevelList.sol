// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./IMobsterLevelList.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title NFT Traits to generate the token URI
/// @author Bounyavong
/// @dev read the traits details from NFT and generate the Token URI
contract MobsterLevelList is OwnableUpgradeable, IMobsterLevelList {
    bytes private mobster_level_list;

    /**
     * @dev initialize function
     */
    function initialize() public virtual initializer {
        mobster_level_list = "556556555555555655555565555555556555556555556555556555575555555555765555565765565555656555655556575565555565565555655565555556566665556555565555655555656555565556565566555565666555666558555555556556555555556655565555555656555555556567565555655565555565556556556565856575555565655556556666555555555555655665555555555655555566555555555655555565556655665555565555656566565655555555656655755555555555557555565555665565655565665565556556556675555555565555565575656555556555556555566576565555555555555555555655565555555556555555656555657556558555555665555555555665556555555556655655656555555656555565655556555555556657565566555566655555555555555655665555555555765556555566565555566556555665655556555655555555565555555565556565556655555555656555655555565857565555555565655665555766565565555565555556555555556555555755556565555555565656555565565555656555555555555555555555555665555555555655565655856665655666565555555555555665665555555565656566656565655555565555556565575555555555555556675655655555556557556555555555555765555556655565555677665555555555555555565555555665655555655555555555555655566556555555556555656556555655556555555665556676565656555555856565565555566555655555566665555565555555655555566556";
    }

    /**
     * @dev get the mobster level by index
     * @param mobsterIndex the choosed mobster index
     * @return level the mobster level
     */
    function getMobsterLevel(uint32 mobsterIndex)
        external
        view
        returns (uint8 level)
    {
        return uint8(mobster_level_list[mobsterIndex]) - 48;
    }

    /**
     * @dev add the mobster level list
     * @param _levels the mobster level list
     */
    function addMobsterLevelList(bytes memory _levels) external onlyOwner {
        mobster_level_list = abi.encodePacked(mobster_level_list, _levels);
    }

    /**
     * @dev set the mobster level list
     * @param _levels the mobster level list
     * @param _generation the generation to set the level list
     */
    function setMobsterLevelList(bytes memory _levels, uint8 _generation)
        external
        onlyOwner
    {
        uint32 start = 0;
        uint32 end = 1200;

        if (_generation > 0) {
            start = 1200 + (_generation - 1) * 600;
            end = start + 600;
        }
        require(
            mobster_level_list.length >= end,
            "Invalid level length and generation"
        );

        for (uint32 i = start; i < end; i++) {
            mobster_level_list[i] = _levels[i - start];
        }
    }
}
