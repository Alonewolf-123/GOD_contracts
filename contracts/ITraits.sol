// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface ITraits {

    // struct to store each token's traits
    struct DwarfTrait {
        bool isMerchant;
        uint32 index;
        uint8 cityId;
        uint8 level;
        uint8 generation;
    }

    function selectTraits(
        uint256 seed,
        bool isMerchant,
        uint8 generation
    ) external returns (DwarfTrait memory aTrait);
}