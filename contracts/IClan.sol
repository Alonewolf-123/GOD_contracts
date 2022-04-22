// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./ITraits.sol";

interface IClan {
    /**
     * @dev adds Merchant and Mobsters to the Clan
     * @param tokenId the ID of the Merchant or Mobster to add to the clan
     * @param trait the trait of the token
     */
    function addOneToClan(uint256 tokenId, ITraits.DwarfTrait calldata trait)
        external;

    /**
     * @dev adds Merchant and Mobsters to the Clan
     * @param tokenIds the IDs of the Merchants and Mobsters to add to the clan
     * @param traits the traits of the tokens
     */
    function addManyToClan(
        uint256[] calldata tokenIds,
        ITraits.DwarfTrait[] calldata traits
    ) external;
}
