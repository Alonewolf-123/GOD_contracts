// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./Ownable.sol";
import "./Pausable.sol";
import "./IDwarfs_NFT.sol";
import "./IClan.sol";
import "./GOD.sol";
import "./Strings.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract Dwarfs_NFT is ERC721Upgradeable, IDwarfs_NFT, Ownable, Pausable {
    using Strings for uint256;

    // eth prices for mint
    uint256[] private MINT_ETH_PRICES = [
        0.0012 ether,
        0.0014 ether,
        0.0016 ether,
        0.0018 ether
    ];

    // god prices for mint
    uint256[] private MINT_GOD_PRICES = [
        0 ether,
        100000 ether,
        120000 ether,
        140000 ether
    ];

    // max number of tokens that can be minted - 20000 in production
    uint256[] private MAX_GEN_TOKENS = [8000, 12000, 16000, 20000];

    // sold amount percent by eth (50%)
    uint256 private MAX_TOKENS_ETH_SOLD = 50;

    // number of mobsters in a city
    uint8[] private MAX_MOBSTERS = [150, 45, 4, 1];

    // number of tokens have been minted so far
    uint16 public minted;

    // mapping from tokenId to a struct containing the token's traits
    mapping(uint256 => DwarfTrait) private tokenTraits;
    // mapping from hashed(tokenTrait) to the tokenId it's associated with
    // used to ensure there are no duplicates
    mapping(uint256 => uint256) private existingCombinations;

    // reference to the Clan for choosing random Mobster thieves
    IClan public clan;
    // reference to $GOD for burning on mint
    GOD public god;

    // traits parameters range
    uint8[] private MAX_TRAITS = [
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255,
        255
    ];

    // Base URI
    string private baseURI;

    // temporary variables
    uint8 private cityId;

    uint16[] private count_mobsters = [0, 0, 0, 0];
    uint8 private totalBosses = 1;
    uint256 totalMobstersPerCity = 200;
    DwarfTrait[] private bossTraits;

    /**
     * instantiates contract and rarity tables
     */
    function initialize(address _god) public virtual initializer {
        __ERC721_init("Game Of Dwarfs", "DWARF");
        god = GOD(_god);
    }

    /** EXTERNAL */
    /**
     * mint a token by owner
     */
    function mintByOwner(uint256 amount, DwarfTrait[] memory s)
        external
        onlyOwner
    {
        require(s.length == amount, "Invalid parameter");
        for (uint256 i = 0; i < amount; i++) {
            if (existingCombinations[structToHash(s[i])] == 0) {
                minted++;
                tokenTraits[minted] = s[i];
                existingCombinations[structToHash(s[i])] = minted;

                _safeMint(_msgSender(), minted);
            }
        }
    }

    /**
     * mint a token - 85% Merchant, 15% Mobsters
     * @param amount the amount of the token
     */
    function mint(uint16 amount) external payable whenNotPaused {
        require(tx.origin == _msgSender(), "Only EOA");
        require(minted + amount <= MAX_GEN_TOKENS[3], "All tokens minted");
        require(amount > 0 && amount <= 30, "Invalid mint amount");
        if (minted < MAX_GEN_TOKENS[0]) {
            require(
                minted + amount <= MAX_GEN_TOKENS[0],
                "All tokens on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICES[0] <= msg.value,
                "Invalid payment amount"
            );
        } else if (
            minted >= MAX_GEN_TOKENS[0] &&
            minted <
            MAX_GEN_TOKENS[0] +
                ((MAX_GEN_TOKENS[1] - MAX_GEN_TOKENS[0]) *
                    MAX_TOKENS_ETH_SOLD) /
                100
        ) {
            require(
                minted + amount <=
                    MAX_GEN_TOKENS[0] +
                        ((MAX_GEN_TOKENS[1] - MAX_GEN_TOKENS[0]) *
                            MAX_TOKENS_ETH_SOLD) /
                        100,
                "All tokens on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICES[1] <= msg.value,
                "Invalid payment amount"
            );
        } else if (
            minted >= MAX_GEN_TOKENS[1] &&
            minted <
            MAX_GEN_TOKENS[1] +
                ((MAX_GEN_TOKENS[2] - MAX_GEN_TOKENS[1]) *
                    MAX_TOKENS_ETH_SOLD) /
                100
        ) {
            require(
                minted + amount <=
                    MAX_GEN_TOKENS[1] +
                        ((MAX_GEN_TOKENS[2] - MAX_GEN_TOKENS[1]) *
                            MAX_TOKENS_ETH_SOLD) /
                        100,
                "All tokens on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICES[2] <= msg.value,
                "Invalid payment amount"
            );
        } else if (
            minted >= MAX_GEN_TOKENS[2] &&
            minted <
            MAX_GEN_TOKENS[2] +
                ((MAX_GEN_TOKENS[3] - MAX_GEN_TOKENS[2]) *
                    MAX_TOKENS_ETH_SOLD) /
                100
        ) {
            require(
                minted + amount <=
                    MAX_GEN_TOKENS[2] +
                        ((MAX_GEN_TOKENS[3] - MAX_GEN_TOKENS[2]) *
                            MAX_TOKENS_ETH_SOLD) /
                        100,
                "All tokens on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICES[3] <= msg.value,
                "Invalid payment amount"
            );
        }

        uint256 totalGodCost = 0;
        for (uint16 i = 0; i < amount; i++) {
            minted++;
            totalGodCost += mintCost(minted);
        }
        if (totalGodCost > 0) god.burn(_msgSender(), totalGodCost);

        uint16[] memory tokenIds = new uint16[](amount);
        uint256 seed;
        minted = minted - amount;
        for (uint16 i = 0; i < amount; i++) {
            if (i == 0 || clan.getAvailableCity() != cityId) {
                cityId = clan.getAvailableCity();
                count_mobsters = clan.getNumMobstersByCityId(cityId);
            }
            minted++;
            seed = random(minted);
            generate(minted, seed);

            _safeMint(address(clan), minted);
            tokenIds[i] = minted;
        }

        clan.addManyToClan(_msgSender(), tokenIds);
    }

    /**
     * the first 8000 are paid in ETH
     * the next 2000 are paid in ETH
     * the next 2000 are 100,000 $GOD
     * the next 2000 are paid in ETH
     * the next 2000 are 120,000 $GOD
     * the next 2000 are paid in ETH
     * the next 2000 are 140,000 $GOD
     * @param tokenId the ID to check the cost of to mint
     * @return the cost of the given token ID
     */
    function mintCost(uint256 tokenId) public view returns (uint256) {
        if (tokenId <= MAX_GEN_TOKENS[0]) return MINT_GOD_PRICES[0];
        else if (
            tokenId <=
            MAX_GEN_TOKENS[0] +
                ((MAX_GEN_TOKENS[1] - MAX_GEN_TOKENS[0]) *
                    MAX_TOKENS_ETH_SOLD) /
                100
        ) return 0;
        else if (tokenId <= MAX_GEN_TOKENS[1]) return MINT_GOD_PRICES[1];
        if (
            tokenId <=
            MAX_GEN_TOKENS[1] +
                ((MAX_GEN_TOKENS[2] - MAX_GEN_TOKENS[1]) *
                    MAX_TOKENS_ETH_SOLD) /
                100
        ) return 0;
        else if (tokenId <= MAX_GEN_TOKENS[2]) return MINT_GOD_PRICES[2];
        else if (
            tokenId <=
            MAX_GEN_TOKENS[2] +
                ((MAX_GEN_TOKENS[3] - MAX_GEN_TOKENS[2]) *
                    MAX_TOKENS_ETH_SOLD) /
                100
        ) return 0;
        else if (tokenId <= MAX_GEN_TOKENS[3]) return MINT_GOD_PRICES[3];

        return 0 ether;
    }

    /**
     * transfer token
     * @param from the address of source
     * @param to the address of destination
     * @param tokenId the token id
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        // Hardcode the Clan's approval so that users don't have to waste gas approving
        if (_msgSender() != address(clan))
            require(
                _isApprovedOrOwner(_msgSender(), tokenId),
                "ERC721: transfer caller is not owner nor approved"
            );
        _transfer(from, to, tokenId);
    }

    /** INTERNAL */

    /**
     * generates traits for a specific token, checking to make sure it's unique
     * @param tokenId the id of the token to generate traits for
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t - a struct of traits for the given token ID
     */
    function generate(uint256 tokenId, uint256 seed)
        internal
        returns (DwarfTrait memory t)
    {
        if (tokenId <= MAX_GEN_TOKENS[0]) {
            t.generation = 0;
        } else if (
            tokenId <= MAX_GEN_TOKENS[1]
        ) {
            t.generation = 1;
        } else if (
            tokenId <= MAX_GEN_TOKENS[2]
        ) {
            t.generation = 2;
        } else {
            t.generation = 3;
        }

        while (true) {
            uint8 alphaIndex = selectDwarfType(seed);
            t = selectTraits(seed, alphaIndex);
            if (existingCombinations[structToHash(t)] == 0) {
                t.cityId = cityId;
                t.isMerchant = (alphaIndex == 0);
                t.alphaIndex = alphaIndex;

                tokenTraits[tokenId] = t;
                existingCombinations[structToHash(t)] = tokenId;
                count_mobsters[t.alphaIndex - 5]++;
                totalMobstersPerCity--;
                if (totalMobstersPerCity == 0) {
                    totalMobstersPerCity =
                        MAX_MOBSTERS[0] +
                        MAX_MOBSTERS[1] +
                        MAX_MOBSTERS[2] +
                        MAX_MOBSTERS[3];
                }
                return t;
            }
        }
    }

    function selectDwarfType(uint256 seed)
        internal
        view
        returns (uint8 alphaIndex)
    {
        uint256 cur_seed = random(seed);
        bool isMerchant = (seed & 0xFFFF) % 100 >= 15;

        if (isMerchant == true) {
            return 0;
        } else {
            cur_seed = random(cur_seed);

            if (
                (cur_seed & 0xFFFF) % totalMobstersPerCity <
                (MAX_MOBSTERS[3] - count_mobsters[3])
            ) {
                return 8;
            } else if (
                (cur_seed & 0xFFFF) % totalMobstersPerCity <
                (MAX_MOBSTERS[2] +
                    MAX_MOBSTERS[3] -
                    count_mobsters[3] -
                    count_mobsters[2])
            ) {
                return 7;
            } else if (
                (cur_seed & 0xFFFF) % totalMobstersPerCity <
                (MAX_MOBSTERS[1] +
                    MAX_MOBSTERS[2] +
                    MAX_MOBSTERS[3] -
                    count_mobsters[3] -
                    count_mobsters[2] -
                    count_mobsters[1])
            ) {
                return 6;
            } else if (
                (cur_seed & 0xFFFF) % totalMobstersPerCity <
                totalMobstersPerCity
            ) {
                return 5;
            } else {
                return 0;
            }
        }
    }

    /**
     * selects the species and all of its traits based on the seed value
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t -  a struct of randomly selected traits
     */
    function selectTraits(uint256 seed, uint8 alphaIndex)
        internal
        view
        returns (DwarfTrait memory t)
    {
        // if Boss
        if (alphaIndex == 7) {
            // set the custom traits
            t.background_weapon = bossTraits[totalBosses].background_weapon;
            t.body_outfit = bossTraits[totalBosses].body_outfit;
            t.head_ears = bossTraits[totalBosses].head_ears;
            t.mouth_nose = bossTraits[totalBosses].mouth_nose;
            t.eyes_brows = bossTraits[totalBosses].eyes_brows;
            t.hair_facialhair = bossTraits[totalBosses].hair_facialhair;
            t.eyewear = bossTraits[totalBosses].eyewear;
        } else {
            t.background_weapon =
                uint16((random(seed) % MAX_TRAITS[0]) << 8) +
                uint8(random(seed + 1) % MAX_TRAITS[1]);
            t.body_outfit =
                uint16((random(seed + 2) % MAX_TRAITS[2]) << 8) +
                uint8(random(seed + 3) % MAX_TRAITS[3]);
            t.head_ears =
                uint16((random(seed + 4) % MAX_TRAITS[4]) << 8) +
                uint8(random(seed + 5) % MAX_TRAITS[5]);
            t.mouth_nose =
                uint16((random(seed + 6) % MAX_TRAITS[6]) << 8) +
                uint8(random(seed + 7) % MAX_TRAITS[7]);
            t.eyes_brows =
                uint16((random(seed + 8) % MAX_TRAITS[8]) << 8) +
                uint8(random(seed + 9) % MAX_TRAITS[9]);
            t.hair_facialhair =
                uint16((random(seed + 10) % MAX_TRAITS[10]) << 8) +
                uint8(random(seed + 11) % MAX_TRAITS[11]);
            t.eyewear = uint8(random(seed + 12) % MAX_TRAITS[12]);
        }

        return t;
    }

    /**
     * converts a struct to a 256 bit hash to check for uniqueness
     * @param s the struct to pack into a hash
     * @return the 256 bit hash of the struct
     */
    function structToHash(DwarfTrait memory s) internal pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        s.background_weapon,
                        s.body_outfit,
                        s.head_ears,
                        s.mouth_nose,
                        s.eyes_brows,
                        s.hair_facialhair,
                        s.eyewear
                    )
                )
            );
    }

    /**
     * generates a pseudorandom number
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

    /** READ */
    /**
     * get the token traits details
     * @param tokenId the token id
     * @return DwarfTrait memory
     */
    function getTokenTraits(uint256 tokenId)
        external
        view
        override
        returns (DwarfTrait memory)
    {
        return tokenTraits[tokenId];
    }

    /** ADMIN */

    /**
     * called after deployment so that the contract can get random mobster thieves
     * @param _clan the address of the Clan
     */
    function setClan(address _clan) external onlyOwner {
        clan = IClan(_clan);
    }

    /**
     * allows owner to withdraw funds from minting
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * updates the number of tokens for sale
     * @param _genNumTokens the number of tokens array
     */
    function setGenTokens(uint256[] memory _genNumTokens) external onlyOwner {
        require(
            _genNumTokens.length == MAX_GEN_TOKENS.length,
            "Invalid input parameter"
        );
        for (uint8 i = 0; i < _genNumTokens.length; i++) {
            MAX_GEN_TOKENS[i] = _genNumTokens[i];
        }
    }

    function getGenTokens() external view returns (uint256[] memory _prices) {
        return MAX_GEN_TOKENS;
    }

    /**
     * set the ETH prices
     * @param _prices the prices array
     */
    function setMintETHPrices(uint256[] memory _prices) external onlyOwner {
        require(
            _prices.length == MINT_ETH_PRICES.length,
            "Invalid input parameter"
        );
        for (uint8 i = 0; i < _prices.length; i++) {
            MINT_ETH_PRICES[i] = _prices[i];
        }
    }

    function getMintETHPrices()
        external
        view
        returns (uint256[] memory _prices)
    {
        return MINT_ETH_PRICES;
    }

    /**
     * set the GOD prices
     * @param _prices the prices array
     */
    function setMintGODPrices(uint256[] memory _prices) external onlyOwner {
        require(
            _prices.length == MINT_GOD_PRICES.length,
            "Invalid input parameter"
        );
        for (uint8 i = 0; i < _prices.length; i++) {
            MINT_GOD_PRICES[i] = _prices[i];
        }
    }

    function getMintGODPrices()
        external
        view
        returns (uint256[] memory _prices)
    {
        return MINT_GOD_PRICES;
    }

    /**
     * set the ETH percent
     * @param _percent the percent of ETH
     */
    function setEthSoldPercent(uint256 _percent) external onlyOwner {
        MAX_TOKENS_ETH_SOLD = _percent;
    }

    function getEthSoldPercent() external view returns (uint256 _percent) {
        return MAX_TOKENS_ETH_SOLD;
    }

    /**
     * set the traits values
     * @param maxValues the max values of the traits
     */
    function setMaxTraitValues(uint8[] memory maxValues) external onlyOwner {
        require(
            maxValues.length == MAX_TRAITS.length,
            "Invalid input parameter"
        );
        for (uint8 i = 0; i < maxValues.length; i++) {
            MAX_TRAITS[i] = maxValues[i];
        }
    }

    function getMaxTraitValues()
        external
        view
        returns (uint8[] memory maxValues)
    {
        return MAX_TRAITS;
    }

    function setMaxMobsters(uint8[] memory maxValues) external onlyOwner {
        require(
            maxValues.length == MAX_MOBSTERS.length,
            "Invalid input parameter"
        );

        totalMobstersPerCity = 0;
        for (uint8 i = 0; i < maxValues.length; i++) {
            MAX_MOBSTERS[i] = maxValues[i];
            totalMobstersPerCity += MAX_MOBSTERS[i];
        }
    }

    function getMaxMobsters() external view returns (uint8[] memory maxValues) {
        return MAX_MOBSTERS;
    }

    function setBossTraits(DwarfTrait memory traits, uint8 index)
        external
        onlyOwner
    {
        require(
            index < MAX_MOBSTERS[2] * clan.getMaxNumCity(),
            "Invalid parameter"
        );

        if (index >= bossTraits.length) {
            bossTraits.push(traits);
        } else {
            bossTraits[index] = traits;
        }
    }

    function getBossTraits()
        external
        view
        returns (DwarfTrait[] memory traits)
    {
        return bossTraits;
    }

    /**
     * enables owner to pause / unpause minting
     */
    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    /**
     * @dev Internal function to set the base URI for all token IDs. It is
     * automatically added as a prefix to the value returned in {tokenURI},
     * or to the token ID if {tokenURI} is empty.
     */
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    /**
     * @dev Returns the base URI set via {setBaseURI}. This will be
     * automatically added as a prefix in {tokenURI} to each token's URI, or
     * to the token ID if no specific URI is set for that token ID.
     */
    function getBaseURI() public view returns (string memory) {
        return baseURI;
    }

    /** RENDER */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        IDwarfs_NFT.DwarfTrait memory s = tokenTraits[tokenId];
        bytes memory t = new bytes(13);
        t[0] = bytes1((uint8)(s.background_weapon >> 8));
        t[1] = bytes1((uint8)(s.background_weapon & 0x00FF));

        t[2] = bytes1((uint8)(s.body_outfit >> 8));
        t[3] = bytes1((uint8)(s.body_outfit & 0x00FF));

        t[4] = bytes1((uint8)(s.head_ears >> 8));
        t[5] = bytes1((uint8)(s.head_ears & 0x00FF));

        t[6] = bytes1((uint8)(s.mouth_nose >> 8));
        t[7] = bytes1((uint8)(s.mouth_nose & 0x00FF));

        t[8] = bytes1((uint8)(s.eyes_brows >> 8));
        t[9] = bytes1((uint8)(s.eyes_brows & 0x00FF));

        t[10] = bytes1((uint8)(s.hair_facialhair >> 8));
        t[11] = bytes1((uint8)(s.hair_facialhair & 0x00FF));

        t[12] = bytes1(s.eyewear);

        string memory _tokenURI = base64(t);

        // If there is no base URI, return the token URI.
        if (bytes(baseURI).length == 0) {
            return string(abi.encodePacked(_tokenURI, ".json"));
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(baseURI, _tokenURI, ".json"));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    }

    string internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    function base64(bytes memory data) internal pure returns (string memory) {
        if (data.length == 0) return "";

        // load the table into memory
        string memory table = TABLE;

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((data.length + 2) / 3);

        // add some extra buffer at the end required for the writing
        string memory result = new string(encodedLen + 32);

        assembly {
            // set the actual output length
            mstore(result, encodedLen)

            // prepare the lookup table
            let tablePtr := add(table, 1)

            // input ptr
            let dataPtr := data
            let endPtr := add(dataPtr, mload(data))

            // result ptr, jump over length
            let resultPtr := add(result, 32)

            // run over the input, 3 bytes at a time
            for {

            } lt(dataPtr, endPtr) {

            } {
                dataPtr := add(dataPtr, 3)

                // read 3 bytes
                let input := mload(dataPtr)

                // write 4 characters
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
                mstore(
                    resultPtr,
                    shl(248, mload(add(tablePtr, and(input, 0x3F))))
                )
                resultPtr := add(resultPtr, 1)
            }

            // padding with '='
            switch mod(mload(data), 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }
        }

        return result;
    }
}
