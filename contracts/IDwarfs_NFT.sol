// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

interface IDwarfs_NFT {

  // struct to store each token's traits
  struct DwarfTrait {
    bool isMerchant;
    uint8 background_weapon;
    uint8 body_outfit;
    uint8 head;
    uint8 mouth;
    uint8 eyes_brows_wear;
    uint8 nose;
    uint8 hair_facialhair;
    uint8 ears;
    uint8 alphaIndex;
  }


  function getGen0Tokens() external view returns (uint256);
  function getTokenTraits(uint256 tokenId) external view returns (DwarfTrait memory);
}