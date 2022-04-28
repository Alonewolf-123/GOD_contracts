// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./Random.sol";
import "./ITraits.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title NFT Traits to generate the token URI
/// @author Bounyavong
/// @dev read the traits details from NFT and generate the Token URI
contract Traits is OwnableUpgradeable, ITraits {
    // randomized moster level list
    uint256[] private mobster_level_list;

    // mapping from mobster index to a existed flag
    mapping(uint256 => uint256) private mapMobsterIndexExisted;

    struct ContractInfo {
        uint32 merchantStartIndex;
        uint32 count_mobsters;
    }
    ContractInfo public contractInfo;

    // reference to the Dwarfs_NFT NFT contract
    address public dwarfs_nft;

    /**
     * @dev initialize function
     */
    function initialize() public virtual initializer {
        __Ownable_init();

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
        returns (uint32 level)
    {
        uint256 _index = mobsterIndex % 100;
        level = uint32(((mobster_level_list[mobsterIndex / 100] & (0x03 << (_index * 2))) >> (_index * 2)) + 5);
    }

    /**
     * @dev selects the species and all of its traits based on the seed value
     * @param countMerchant count of Merchants
     * @param countMobster count of Mobsters
     * @return traits -  a struct array of randomly selected traits
     */
    function selectTraits(
        uint256 countMerchant,
        uint256 countMobster
    ) external returns (DwarfTrait[] memory traits) {
        require(_msgSender() == dwarfs_nft, "CALLER_NOT_DWARF");

        uint256 countDwarfs = countMerchant + countMobster;
        traits = new DwarfTrait[](countDwarfs);

        if (countMerchant > 0) {
            // if it's a merchant
            for (uint256 i = 0; i < countMerchant; i++) {
                traits[i].index = uint32(contractInfo.merchantStartIndex + i);
            }
            contractInfo.merchantStartIndex += uint32(countMerchant);
        }

        if (countMobster > 0) {
            // if it's a mobster
            for (uint256 i = countMerchant; i < countDwarfs; i++) {
                traits[i].level = getMobsterLevel(contractInfo.count_mobsters);
                traits[i].cityId = uint32(contractInfo.count_mobsters / 200) + 1;
                contractInfo.count_mobsters++;
                traits[i].index = uint32(contractInfo.count_mobsters);

            }
        }
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
    function setMobsterLevelList(uint256[] calldata _levels) external onlyOwner {
        require(mobster_level_list[0] == 0, "SET_ALREADY");
        require(_levels.length == 30, "INVALID_PARAMS");
        mobster_level_list = new uint256[](30);
        for (uint i = 0; i < 30; i++) {
            mobster_level_list[i] = _levels[i];
        }
    }
}
