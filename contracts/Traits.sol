// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./ITraits.sol";
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

    // static boss traits
    DwarfTrait[] public bossTraits;

    // static dwarfather traits
    DwarfTrait[] public dwarfatherTraits;

    // array of the unallocated traits
    string[] public unallocatedTraits;

    // array of the allocated traits
    string[] public allocatedTraits;

    /**
     * @dev initialize function
     */
    function initialize() public virtual initializer {
        __Ownable_init();
    }

    /**
     * @dev selects the species and all of its traits based on the seed value
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t -  a struct of randomly selected traits
     */
    function selectTraits(
        uint256 seed,
        uint8 level,
        uint8 totalBosses,
        uint8 totalDwarfathers
    ) external returns (DwarfTrait memory t) {
        // if Boss
        if (level == 7) {
            // set the custom traits to boss
            t = bossTraits[totalBosses];
        } else if (level == 8) {
            // set the custom traits to dwarfather
            t = dwarfatherTraits[totalDwarfathers];
        } else {
            uint256 m_TraitIndex = random(seed) % unallocatedTraits.length;
            string memory traitStr = unallocatedTraits[m_TraitIndex];
            t = parseStringToTrait(traitStr);

            allocatedTraits.push(traitStr);
            delete unallocatedTraits[m_TraitIndex];
        }

        return t;
    }

    /**
     * @dev parse the base64 encoded string to traits
     * @param traitStr a base64 encoded string
     * @return t -  a struct of parsed traits
     */
    function parseStringToTrait(string memory traitStr)
        internal
        pure
        returns (DwarfTrait memory t)
    {
        bytes memory traitBytes = traitStr.base64Decode();
        t.background_weapon =
            uint16(uint8(traitBytes[0]) << 8) + // background
            uint8(traitBytes[1]); // weapon
        t.body_outfit =
            uint16(uint8(traitBytes[2]) << 8) + // body
            uint8(traitBytes[3]); // outfit
        t.head_ears =
            uint16(uint8(traitBytes[4]) << 8) + // head
            uint8(traitBytes[5]); // ears
        t.mouth_nose =
            uint16(uint8(traitBytes[6]) << 8) + // mouth
            uint8(traitBytes[7]); // nose
        t.eyes_brows =
            uint16(uint8(traitBytes[8]) << 8) + // eyes
            uint8(traitBytes[9]); // eyebrows
        t.hair_facialhair =
            uint16(uint8(traitBytes[10]) << 8) + // hair
            uint8(traitBytes[11]); // facialhair
        t.eyewear = uint8(traitBytes[12]); // eyewear
        t.cityId = uint8(traitBytes[13]); // city id
        t.level = uint8(traitBytes[14]); // level
        t.generation = uint8(traitBytes[15]); // generation
    }

    /**
     * @dev converts a struct to a 256 bit hash to check for uniqueness
     * @param aTrait the struct to pack into a hash
     * @return the 256 bit hash of the struct
     */
    function getTraitHash(DwarfTrait memory aTrait)
        external
        pure
        returns (uint256)
    {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        aTrait.background_weapon, // background & weapon
                        aTrait.body_outfit, // body & outfit
                        aTrait.head_ears, // head & ears
                        aTrait.mouth_nose, // mouth & nose
                        aTrait.eyes_brows, // eyes & eyebrows
                        aTrait.hair_facialhair, // hair & facialhair
                        aTrait.eyewear, // eyewear
                        aTrait.cityId, // city id
                        aTrait.level, // level
                        aTrait.generation // generation
                    )
                )
            );
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
     * @dev Returns the token URI.
     * @param aTrait the trait of a token
     * @return _tokenURI URI string
     */
    function getTokenURI(DwarfTrait memory aTrait)
        public
        pure
        returns (string memory _tokenURI)
    {
        bytes memory t = new bytes(16);
        t[0] = bytes1((uint8)(aTrait.background_weapon >> 8)); // add the background into bytes
        t[1] = bytes1((uint8)(aTrait.background_weapon & 0x00FF)); // add the weapon into bytes

        t[2] = bytes1((uint8)(aTrait.body_outfit >> 8)); // add the body into bytes
        t[3] = bytes1((uint8)(aTrait.body_outfit & 0x00FF)); // add the outfit into bytes

        t[4] = bytes1((uint8)(aTrait.head_ears >> 8)); // add the head into bytes
        t[5] = bytes1((uint8)(aTrait.head_ears & 0x00FF)); // add the ears into bytes

        t[6] = bytes1((uint8)(aTrait.mouth_nose >> 8)); // add the mouth into bytes
        t[7] = bytes1((uint8)(aTrait.mouth_nose & 0x00FF)); // add the nose into bytes

        t[8] = bytes1((uint8)(aTrait.eyes_brows >> 8)); // add the eyes into bytes
        t[9] = bytes1((uint8)(aTrait.eyes_brows & 0x00FF)); // add the eyebrows into bytes

        t[10] = bytes1((uint8)(aTrait.hair_facialhair >> 8)); // add the hair into bytes
        t[11] = bytes1((uint8)(aTrait.hair_facialhair & 0x00FF)); // add the facialhair into bytes

        t[12] = bytes1(aTrait.eyewear); // add the eyewear into bytes
        t[13] = bytes1(aTrait.cityId); // add the city id into bytes
        t[14] = bytes1(aTrait.level); // add the level into bytes
        t[15] = bytes1(aTrait.generation); // add the generation into bytes

        _tokenURI = t.base64Encode();
    }

    /**
     * @dev set the traits of boss
     * @param traits the trait of a boss
     * @param index the boss index
     */
    function setBossTraits(DwarfTrait memory traits, uint16 index)
        external
        onlyOwner
    {
        if (index >= bossTraits.length) {
            bossTraits.push(traits);
        } else {
            bossTraits[index] = traits;
        }
    }

    /**
     * @dev set the traits of dwarfather
     * @param traits the trait of a boss
     * @param index the boss index
     */
    function setDwarfatherTraits(DwarfTrait memory traits, uint16 index)
        external
        onlyOwner
    {
        if (index >= dwarfatherTraits.length) {
            dwarfatherTraits.push(traits);
        } else {
            dwarfatherTraits[index] = traits;
        }
    }

    /**
     * @dev set the traits of NFT (except the dwarfather and boss)
     * @param traits the trait of NFT
     */
    function setNFTTraits(string[] memory traits) external onlyOwner {
        unallocatedTraits = traits;
    }

    /**
     * @dev add the new traits of NFT (except the dwarfather and boss)
     * @param traits the trait of NFT
     */
    function addNewNFTTraits(string[] memory traits) external onlyOwner {
        for (uint256 i = 0; i < traits.length; i++)
            unallocatedTraits.push(traits[i]);
    }
}
