// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface ITraits {

    // struct to store each token's traits
    struct DwarfTrait {
        uint32 index;
        uint32 cityId;
        uint32 level;
        uint32 generation;
    }

    function selectTraits(
        uint32 generation,
        uint256 countMerchant,
        uint256 countMobster
    ) external returns (DwarfTrait[] memory traits);
}