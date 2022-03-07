// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./IDwarfs_NFT.sol";

interface ITraits {
    function getTokenURI(uint32 tokenId) external view returns (string memory);

    function selectTraits(
        uint256 seed,
        uint8 alphaIndex,
        uint8 totalBosses,
        uint8 totalDwarfathers
    ) external view returns (IDwarfs_NFT.DwarfTrait memory t);

    function getTraitHash(IDwarfs_NFT.DwarfTrait memory s)
        external
        pure
        returns (uint256);
}
