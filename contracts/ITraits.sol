// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface ITraits {

    // struct to store each token's traits
    struct DwarfTrait {
        bool isMerchant;
        uint16 background_weapon;
        uint16 body_outfit;
        uint16 head_ears;
        uint16 mouth_nose;
        uint16 eyes_brows;
        uint16 hair_facialhair;
        uint8 eyewear;
        uint8 cityId;
        uint8 level;
        uint8 generation;
    }

    function getTokenURI(DwarfTrait memory aTrait) external view returns (string memory);

    function selectTraits(
        uint256 seed,
        uint8 level,
        uint8 totalBosses,
        uint8 totalDwarfathers
    ) external returns (DwarfTrait memory aTrait);

    function getTraitHash(DwarfTrait memory aTrait)
        external
        pure
        returns (uint256);
}
