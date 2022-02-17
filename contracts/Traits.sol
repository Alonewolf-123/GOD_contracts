// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./ITraits.sol";
import "./IDwarfs_NFT.sol";
import "./Strings.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";

/// @title NFT Traits to generate the token URI
/// @author Bounyavong
/// @dev read the traits details from NFT and generate the Token URI
contract Traits is Initializable, ContextUpgradeable, ITraits {
    using Strings for bytes;
    using Strings for uint256;

    IDwarfs_NFT public dwarfs_nft;

    // owner address
    address private _owner;

    /**
     * @dev initialize function
     */
    function initialize() public virtual initializer {}

    /** ADMIN */
    /**
     * @dev set the dwarf NFT address by only owner
     */
    function setDwarfs_NFT(address _dwarfs_nft) external onlyOwner {
        dwarfs_nft = IDwarfs_NFT(_dwarfs_nft);
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev set the address of the new owner.
     */
    function _setOwner(address newOwner) private {
        _owner = newOwner;
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
}
