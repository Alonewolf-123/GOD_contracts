// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./ITraits.sol";

interface IDwarfs_NFT {

    function getTokenTraits(uint32 tokenId)
        external
        view
        returns (ITraits.DwarfTrait memory);
}
