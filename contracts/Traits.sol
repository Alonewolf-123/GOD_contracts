// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./ITraits.sol";
import "./IMobsterLevelList.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title NFT Traits to generate the token URI
/// @author Bounyavong
/// @dev read the traits details from NFT and generate the Token URI
contract Traits is OwnableUpgradeable, ITraits {
    // mapping from mobster index to a existed flag
    mapping(uint32 => uint32) private mapMobsterIndexExisted;

    uint32 private merchantStartIndex;

    uint32 private MAX_MOBSTERS;

    uint32 public count_mobsters;
    uint8 public city_id;
    uint32 public count_merchants;

    IMobsterLevelList public mobsterLevelList;

    // reference to the Dwarfs_NFT NFT contract
    address dwarfs_nft;

    /**
     * @dev initialize function
     */
    function initialize(address _mobsterLevelList) public virtual initializer {
        __Ownable_init();

        MAX_MOBSTERS = 200;

        count_merchants = 0;
        count_mobsters = 200;
        merchantStartIndex = 3001;

        mobsterLevelList = IMobsterLevelList(_mobsterLevelList);
    }

    /**
     * @dev selects the species and all of its traits based on the seed value
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t -  a struct of randomly selected traits
     */
    function selectTraits(
        uint256 seed,
        bool isMerchant,
        uint8 generation
    ) external returns (DwarfTrait memory t) {
        require(
            _msgSender() == dwarfs_nft,
            "Caller Must Be Dwarfs NFT Contract"
        );

        seed = random(seed);
        if (isMerchant == true) {
            // if it's a merchant
            uint32 _index = merchantStartIndex + count_merchants;

            t.index = _index;

            count_merchants++;
        } else {
            // if it's a mobster
            uint32 _index = MAX_MOBSTERS *
                city_id +
                (uint32(seed) % count_mobsters) +
                1;

            if (mapMobsterIndexExisted[_index] == 0) {
                t.index = _index;
            } else {
                t.index = mapMobsterIndexExisted[_index];
            }

            uint32 lastValue = MAX_MOBSTERS * city_id + count_mobsters;
            if (mapMobsterIndexExisted[lastValue] == 0) {
                mapMobsterIndexExisted[_index] = lastValue;
            } else {
                mapMobsterIndexExisted[_index] = mapMobsterIndexExisted[
                    lastValue
                ];
            }

            t.cityId = city_id;
            t.level = mobsterLevelList.getMobsterLevel(t.index - 1);

            count_mobsters--;
            if (count_mobsters == 0) {
                count_mobsters = MAX_MOBSTERS;
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

    /**
     * @dev called after deployment
     * @param _dwarfs_nft the address of the Clan
     */
    function setDwarfs_NFT(address _dwarfs_nft) external onlyOwner {
        dwarfs_nft = _dwarfs_nft;
    }
}
