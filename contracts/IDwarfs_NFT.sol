// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./ITraits.sol";

interface IDwarfs_NFT {
    /** READ */
    /**
     * @dev get the token traits details
     * @param tokenId the token id
     * @return DwarfTrait memory
     */
    function getTokenTraits(uint256 tokenId)
        external
        view
        returns (ITraits.DwarfTrait memory);

    /**
     * @dev get the token traits details
     * @param tokenIds the token ids
     * @return traits DwarfTrait[] memory
     */
    function getBatchTokenTraits(uint256[] calldata tokenIds)
        external
        view
        returns (ITraits.DwarfTrait[] memory traits);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);
}
