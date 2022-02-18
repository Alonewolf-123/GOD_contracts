// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./ITraits.sol";
import "./IDwarfs_NFT.sol";
import "./Strings.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

/// @title NFT Traits to generate the token URI
/// @author Bounyavong
/// @dev read the traits details from NFT and generate the Token URI
contract Traits is Initializable, OwnableUpgradeable, ITraits {
    using Strings for bytes;
    using Strings for uint256;

    // static boss traits
    IDwarfs_NFT.DwarfTrait[] public bossTraits;

    // static dwarfather traits
    IDwarfs_NFT.DwarfTrait[] public dwarfatherTraits;

    // traits parameters range
    uint8[] public MAX_TRAITS;

    IDwarfs_NFT public dwarfs_nft;

    /**
     * @dev initialize function
     */
    function initialize() public virtual initializer {
        // traits parameters range
        MAX_TRAITS = [
            255, // background
            255, // weapon
            255, // body
            255, // outfit
            255, // head
            255, // ears
            255, // mouth
            255, // nose
            255, // eyes
            255, // brows
            255, // hair
            255, // facialhair
            255 // eyewear
        ];
    }

    /** ADMIN */
    /**
     * @dev set the dwarf NFT address by only owner
     */
    function setDwarfs_NFT(address _dwarfs_nft) external onlyOwner {
        dwarfs_nft = IDwarfs_NFT(_dwarfs_nft);
    }

    /**
     * @dev selects the species and all of its traits based on the seed value
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t -  a struct of randomly selected traits
     */
    function selectTraits(uint256 seed, uint8 alphaIndex, uint8 totalBosses, uint8 totalDwarfathers)
        external
        view
        returns (IDwarfs_NFT.DwarfTrait memory t)
    {
        // if Boss
        if (alphaIndex == 7) {
            // set the custom traits to boss
            t = bossTraits[totalBosses];
        } else if (alphaIndex == 8) {
            // set the custom traits to dwarfather
            t = dwarfatherTraits[totalDwarfathers];
        } else {
            t.background_weapon =
                uint16((random(seed) % MAX_TRAITS[0]) << 8) + // background
                uint8(random(seed + 1) % MAX_TRAITS[1]); // weapon
            t.body_outfit =
                uint16((random(seed + 2) % MAX_TRAITS[2]) << 8) + // body
                uint8(random(seed + 3) % MAX_TRAITS[3]); // outfit
            t.head_ears =
                uint16((random(seed + 4) % MAX_TRAITS[4]) << 8) + // head
                uint8(random(seed + 5) % MAX_TRAITS[5]); // ears
            t.mouth_nose =
                uint16((random(seed + 6) % MAX_TRAITS[6]) << 8) + // mouth
                uint8(random(seed + 7) % MAX_TRAITS[7]); // nose
            t.eyes_brows =
                uint16((random(seed + 8) % MAX_TRAITS[8]) << 8) + // eyes
                uint8(random(seed + 9) % MAX_TRAITS[9]); // eyebrows
            t.hair_facialhair =
                uint16((random(seed + 10) % MAX_TRAITS[10]) << 8) + // hair
                uint8(random(seed + 11) % MAX_TRAITS[11]); // facialhair
            t.eyewear = uint8(random(seed + 12) % MAX_TRAITS[12]); // eyewear
        }

        return t;
    }

    /**
     * @dev converts a struct to a 256 bit hash to check for uniqueness
     * @param s the struct to pack into a hash
     * @return the 256 bit hash of the struct
     */
    function getTraitHash(IDwarfs_NFT.DwarfTrait memory s) external pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        s.background_weapon, // background & weapon
                        s.body_outfit, // body & outfit
                        s.head_ears, // head & ears
                        s.mouth_nose, // mouth & nose
                        s.eyes_brows, // eyes & eyebrows
                        s.hair_facialhair, // hair & facialhair
                        s.eyewear // eyewear
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
     * @dev Returns the token URI. BaseURI will be
     * automatically added as a prefix in {tokenURI} to each token's URI, or
     * to the token ID if no specific URI is set for that token ID.
     * @param tokenId the token id
     * @return token URI string
     */
    function tokenURI(uint32 tokenId)
        public
        view
        override
        returns (string memory)
    {
        IDwarfs_NFT.DwarfTrait memory s = dwarfs_nft.getTokenTraits(tokenId);

        bytes memory t = new bytes(13);
        t[0] = bytes1((uint8)(s.background_weapon >> 8)); // add the background into bytes
        t[1] = bytes1((uint8)(s.background_weapon & 0x00FF)); // add the weapon into bytes

        t[2] = bytes1((uint8)(s.body_outfit >> 8)); // add the body into bytes
        t[3] = bytes1((uint8)(s.body_outfit & 0x00FF)); // add the outfit into bytes

        t[4] = bytes1((uint8)(s.head_ears >> 8)); // add the head into bytes
        t[5] = bytes1((uint8)(s.head_ears & 0x00FF)); // add the ears into bytes

        t[6] = bytes1((uint8)(s.mouth_nose >> 8)); // add the mouth into bytes
        t[7] = bytes1((uint8)(s.mouth_nose & 0x00FF)); // add the nose into bytes

        t[8] = bytes1((uint8)(s.eyes_brows >> 8)); // add the eyes into bytes
        t[9] = bytes1((uint8)(s.eyes_brows & 0x00FF)); // add the eyebrows into bytes

        t[10] = bytes1((uint8)(s.hair_facialhair >> 8)); // add the hair into bytes
        t[11] = bytes1((uint8)(s.hair_facialhair & 0x00FF)); // add the facialhair into bytes

        t[12] = bytes1(s.eyewear); // add the eyewear into bytes

        string memory _tokenURI = t.base64();
        string memory _baseURI = dwarfs_nft.getBaseURI();

        // If there is no base URI, return the token URI.
        if (bytes(_baseURI).length == 0) {
            return string(abi.encodePacked(_tokenURI, ".json"));
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(_baseURI, _tokenURI, ".json"));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenId to the baseURI.
        return
            string(
                abi.encodePacked(
                    _baseURI,
                    (uint256(tokenId)).toString(),
                    ".json"
                )
            );
    }

    /**
     * @dev set the traits of boss
     * @param traits the trait of a boss
     * @param index the boss index
     */
    function setBossTraits(IDwarfs_NFT.DwarfTrait memory traits, uint16 index)
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
    function setDwarfatherTraits(IDwarfs_NFT.DwarfTrait memory traits, uint16 index)
        external
        onlyOwner
    {
        if (index >= dwarfatherTraits.length) {
            dwarfatherTraits.push(traits);
        } else {
            dwarfatherTraits[index] = traits;
        }
    }

}
