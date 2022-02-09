// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IDwarfs_NFT {
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
        uint8 alphaIndex;
    }

    function getGen0Tokens() external view returns (uint256);

    function getTokenTraits(uint256 tokenId)
        external
        view
        returns (DwarfTrait memory);
}
