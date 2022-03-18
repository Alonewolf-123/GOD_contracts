// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./ITraits.sol";
// import "./IMobsterLevelList.sol"
import "./Strings.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title NFT Traits to generate the token URI
/// @author Bounyavong
/// @dev read the traits details from NFT and generate the Token URI
contract Traits is OwnableUpgradeable, ITraits {
    using Strings for bytes;
    using Strings for string;
    using Strings for uint256;

    // mapping from mobster index to a existed flag
    mapping(uint32 => bool) private mapMobsterIndexExisted;
    mapping(uint32 => bool) private mapMerchantIndexExisted;

    uint32[] private merchantStartIndex;
    uint32[] private merchantGenLimit;

    uint32 private MAX_MOBSTERS;

    uint32 public count_mobsters;
    uint8 public city_id;
    uint32 public count_merchants;

    /**
     * @dev initialize function
     */
    function initialize() public virtual initializer {
        __Ownable_init();

        MAX_MOBSTERS = 200;

        count_merchants = 0;
        count_mobsters = 0;
        merchantStartIndex = [3001, 9801, 13201, 16601];
        merchantGenLimit = [6800, 3400, 3400, 3400];
    }

    /**
     * @dev selects the species and all of its traits based on the seed value
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t -  a struct of randomly selected traits
     */
    function selectTraits(uint256 seed, bool isMerchant, uint8 generation)
        external
        returns (DwarfTrait memory t)
    {
        string memory traitStr = "";

        seed = random(seed);
        if (isMerchant == true) {
            // if it's a merchant
            uint256 _index = seed % (merchantGenLimit[generation] - count_merchants);
            uint32 _nonExistingCount = 0;
            for (uint32 i = 0; i < merchantGenLimit[generation]; i++) {
                uint32 merchantIndex = merchantStartIndex[generation] + i;
                if (mapMerchantIndexExisted[merchantIndex] == false) {
                    if (_index == _nonExistingCount) {
                        t.index = merchantIndex;
                        mapMerchantIndexExisted[merchantIndex] = true;
                        break;
                    }
                    _nonExistingCount++;
                }
            }
            count_merchants++;
            if (count_merchants == merchantGenLimit[generation]) {
                count_merchants = 0;
            }
        } else {
            // if it's a mobster
            uint256 _index = seed % (MAX_MOBSTERS - count_mobsters);
            uint32 _nonExistingCount = 0;
            uint32 mobsterIndex = 0;
            for (uint32 i = 0; i < MAX_MOBSTERS; i++) {
                mobsterIndex = MAX_MOBSTERS * city_id + i + 1;
                if (mapMobsterIndexExisted[mobsterIndex] == false) {
                    if (_index == _nonExistingCount) {
                        t.index = mobsterIndex;
                        mapMobsterIndexExisted[mobsterIndex] = true;
                        break;
                    }
                    _nonExistingCount++;
                }
            }
            t.cityId = city_id;
            // t.level = mobsterLevelList.getMobsterLevel(mobsterIndex);
            count_mobsters++;

            if (count_mobsters == MAX_MOBSTERS) {
                count_mobsters = 0;
                city_id++;
            }

        }

        t.isMerchant = isMerchant;
        t.generation = generation;
    }

    /**
     * @dev generates a pseudorandom number
     * @param seed a value ensure different outcomes for different sources in the same block
     * @return a pseudorandom value
     */
    function random(uint256 seed) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        tx.origin,
                        blockhash(block.number - 1),
                        block.timestamp,
                        seed
                    )
                )
            );
    }
}
