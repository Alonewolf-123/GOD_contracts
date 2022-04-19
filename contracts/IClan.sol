// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./ITraits.sol";

interface IClan {
    /**
     * @dev adds Merchant and Mobsters to the Clan and Pack
     * @param tokenIds the IDs of the Merchant and Mobsters to add to the clan
     */
    function addManyToClan(
        uint256[] calldata tokenIds,
        ITraits.DwarfTrait[] calldata traits
    ) external;
}
