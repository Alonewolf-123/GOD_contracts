// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./ITraits.sol";

interface IDwarfs_NFT {

    function getTokenTraits(uint256 tokenId)
        external
        view
        returns (ITraits.DwarfTrait memory);
}
