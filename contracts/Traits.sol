// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./ITraits.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title NFT Traits to generate the token URI
/// @author Bounyavong
/// @dev read the traits details from NFT and generate the Token URI
contract Traits is OwnableUpgradeable, ITraits {
    // randomized moster level list
    bytes public mobster_level_list;

    // mapping from mobster index to a existed flag
    mapping(uint256 => uint256) private mapMobsterIndexExisted;

    struct ContractInfo {
        uint32 merchantStartIndex;
        uint32 city_id;
        uint32 count_mobsters;
        uint32 count_merchants;
        uint32 MAX_MOBSTERS;
    }
    ContractInfo public contractInfo;

    // reference to the Dwarfs_NFT NFT contract
    address public dwarfs_nft;

    /**
     * @dev initialize function
     */
    function initialize() public virtual initializer {
        __Ownable_init();

        mobster_level_list = "55655655555555565555556555555555655555655555655555655557555555555576555556576556555565655565555657556555556556555565556555555656666555655556555565555565655556555656556655556566655566655855555555655655";

        contractInfo.MAX_MOBSTERS = 200;
        contractInfo.count_mobsters = 200;
        contractInfo.merchantStartIndex = 3001;
    }

    /**
     * @dev get the mobster level by index
     * @param mobsterIndex the choosed mobster index
     * @return level the mobster level
     */
    function getMobsterLevel(uint256 mobsterIndex)
        internal
        view
        returns (uint32)
    {
        return
            uint32(
                uint8(
                    mobster_level_list[mobsterIndex % contractInfo.MAX_MOBSTERS]
                ) - 48
            );
    }

    /**
     * @dev selects the species and all of its traits based on the seed value
     * @param generation generation of the token
     * @param countMerchant count of Merchants
     * @param countMobster count of Mobsters
     * @return traits -  a struct array of randomly selected traits
     */
    function selectTraits(
        uint32 generation,
        uint256 countMerchant,
        uint256 countMobster
    ) external returns (DwarfTrait[] memory traits) {
        require(_msgSender() == dwarfs_nft, "CALLER_NOT_DWARF");

        uint256 countDwarfs = countMerchant + countMobster;
        traits = new DwarfTrait[](countDwarfs);
        uint256 _index;

        if (countMerchant > 0) {
            // if it's a merchant
            _index = contractInfo.merchantStartIndex + contractInfo.count_merchants;
            for (uint256 i = 0; i < countMerchant; i++) {
                traits[i].index = uint32(_index + i);
                traits[i].generation = generation;
            }
            contractInfo.count_merchants += uint32(countMerchant);
        }

        if (countMobster > 0) {
            // if it's a mobster
            uint256 seed = random(countDwarfs);

            uint256 lastValue;
            uint256 count_mobsters = contractInfo.count_mobsters;
            for (uint256 i = countMerchant; i < countDwarfs; i++) {
                _index =
                    contractInfo.MAX_MOBSTERS *
                    contractInfo.city_id +
                    (seed % count_mobsters) +
                    1;

                if (mapMobsterIndexExisted[_index] == 0) {
                    traits[i].index = uint32(_index);
                } else {
                    traits[i].index = uint32(mapMobsterIndexExisted[_index]);
                }

                lastValue =
                    contractInfo.MAX_MOBSTERS *
                    contractInfo.city_id +
                    count_mobsters;
                if (mapMobsterIndexExisted[lastValue] == 0) {
                    mapMobsterIndexExisted[_index] = lastValue;
                } else {
                    mapMobsterIndexExisted[_index] = mapMobsterIndexExisted[
                        lastValue
                    ];
                }

                traits[i].cityId = contractInfo.city_id + 1;
                traits[i].level = getMobsterLevel(traits[i].index - 1);
                traits[i].generation = generation;

                count_mobsters--;
                if (count_mobsters == 0) {
                    count_mobsters = contractInfo.MAX_MOBSTERS;
                    contractInfo.city_id++;
                }
                seed = (seed >> 8);
            }
            contractInfo.count_mobsters = uint32(count_mobsters);
        }
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
     * @param _dwarfs_nft the address of the NFT
     */
    function setDwarfs_NFT(address _dwarfs_nft) external onlyOwner {
        dwarfs_nft = _dwarfs_nft;
    }

    /**
     * @dev set the mobster level list
     * @param _levels the mobster level list
     */
    function setMobsterLevelList(string calldata _levels) external onlyOwner {
        mobster_level_list = abi.encodePacked(_levels);
    }
}
