// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./Ownable.sol";
import "./Pausable.sol";
import "./IDwarfs_NFT.sol";
import "./IClan.sol";
import "./GOD.sol";
import "./Strings.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

/// @title Dwarfs NFT
/// @author Bounyavong
/// @dev Dwarfs NFT logic is implemented and this is the updradeable
contract Dwarfs_NFT is ERC721Upgradeable, IDwarfs_NFT, Ownable, Pausable {
    using Strings for uint256;

    // eth prices for mint
    uint256[] private MINT_ETH_PRICES = [
        0.0012 ether, // ETH price in Gen0
        0.0014 ether, // ETH price in Gen1
        0.0016 ether, // ETH price in Gen2
        0.0018 ether // ETH price in Gen3
    ];

    // god prices for mint
    uint256[] private MINT_GOD_PRICES = [
        0 ether, // GOD price in Gen0
        100000 ether, // GOD price in Gen1
        120000 ether, // GOD price in Gen2
        140000 ether // GOD price in Gen3
    ];

    // max number of tokens that can be minted in each phase- 20000 in production
    uint256[] private MAX_GEN_TOKENS = [
        8000, // number of tokens in Gen0
        12000, // number of tokens in Gen1
        16000, // number of tokens in Gen2
        20000
    ]; // number of tokens in Gen3

    // sold amount percent by eth (50%)
    uint256 private MAX_TOKENS_ETH_SOLD = 50;

    // number of dwarfs in a city
    uint16[] private MAX_DWARFS_CITY = [
        1133, // max merchants in a city
        150, // max dwarfsoldiers in a city
        45, // max dwarfcapos in a city
        4, // max boss in a city
        1
    ]; // max dwarfather in a city

    // number of tokens have been minted so far
    uint32 public minted;

    // mapping from tokenId to a struct containing the token's traits
    mapping(uint32 => DwarfTrait) private mapTokenTraits;
    // mapping from hashed(tokenTrait) to the tokenId it's associated with
    // used to ensure there are no duplicates
    mapping(uint256 => uint32) private mapTraithashToken;

    // reference to the Clan
    IClan public clan;
    // reference to $GOD for burning in mint
    GOD public god;

    // traits parameters range
    uint8[] private MAX_TRAITS = [
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

    // Base URI
    string private baseURI;

    // current chosen city ID
    uint8 private cityId;

    // number of dwarfs in the current city
    uint16[] private count_dwarfs = [0, 0, 0, 0, 0];

    // current number of boss
    uint8 private totalBosses = 1;

    // the rest number of dwarfs in the current city
    uint16 totalDwarfsPerCity = 1333;

    // static boss traits
    DwarfTrait[] private bossTraits;

    // current generation number of NFT
    uint8 generationOfNft = 0;

    /**
     * @dev instantiates contract and rarity tables
     * @param _god the GOD address
     */
    function initialize(address _god) public virtual initializer {
        __ERC721_init("Game Of Dwarfs", "DWARF");
        god = GOD(_god);
    }

    /**
     * @dev mint a token by owner
     * @param amount the mint amount
     * @param s the traits array
     */
    function mintByOwner(uint16 amount, DwarfTrait[] memory s)
        external
        onlyOwner
    {
        require(s.length == amount, "Invalid parameter");
        for (uint16 i = 0; i < amount; i++) {
            if (mapTraithashToken[getTraitHash(s[i])] == 0) {
                minted++;
                mapTokenTraits[minted] = s[i];
                mapTraithashToken[getTraitHash(s[i])] = minted;

                _safeMint(_msgSender(), minted);
            }
        }
    }

    /**
     * @dev mint a token - 85% Merchant, 15% Mobsters
     * @param amount the amount of the token
     */
    function mint(uint16 amount) external payable whenNotPaused {
        require(tx.origin == _msgSender(), "Only EOA");
        require(minted + amount <= MAX_GEN_TOKENS[3], "All tokens minted");
        require(amount > 0 && amount <= 30, "Invalid mint amount");
        if (minted < MAX_GEN_TOKENS[0]) {
            require(
                minted + amount <= MAX_GEN_TOKENS[0],
                "All tokens of generation 0 on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICES[0] <= msg.value,
                "Invalid ETH payment amount"
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
                "All tokens of generation 1 on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICES[1] <= msg.value,
                "Invalid ETH payment amount"
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
                "All tokens of generation 2 on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICES[2] <= msg.value,
                "Invalid ETH payment amount"
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
                "All tokens of generation 3 on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICES[3] <= msg.value,
                "Invalid ETH payment amount"
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
                count_dwarfs = clan.getNumDwarfsByCityId(cityId);
            }

            minted++;
            if (minted > MAX_GEN_TOKENS[generationOfNft]) {
                generationOfNft++;
            }
            seed = random(minted);
            generate(minted, seed);

            _safeMint(address(clan), minted);
            tokenIds[i] = minted;
        }

        clan.addManyToClan(tokenIds);
    }

    /**
     * @dev the calculate the cost of mint by the Generation
     * @param tokenId the ID to check the cost of to mint
     * @return the GOD cost of the given token ID
     */
    function mintCost(uint32 tokenId) public view returns (uint256) {
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

        return 0;
    }

    /**
     * @dev transfer token
     * @param from the address of source
     * @param to the address of destination
     * @param tokenId the token id
     */
    function transferFrom(
        address from,
        address to,
        uint32 tokenId
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        _transfer(from, to, tokenId);
    }

    /**
     * @dev The rest of Dwarfs will be Merchant in each generation
     * @param tokenId the token id
     * @return if contant merchant, true or false
     */
    function isConstantMerchant(uint32 tokenId) internal view returns (bool) {
        if (
            tokenId >
            getMaxDwarfsPerCity() *
                (clan.getMaxNumCityOfGen()[generationOfNft]) &&
            tokenId <= MAX_GEN_TOKENS[generationOfNft]
        ) {
            return true;
        }

        return false;
    }

    /**
     * @dev generates traits for a specific token, checking to make sure it's unique
     * @param tokenId the id of the token to generate traits for
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t - a struct of traits for the given token ID
     */
    function generate(uint32 tokenId, uint256 seed)
        internal
        returns (DwarfTrait memory t)
    {
        // check the merchant or mobster
        uint8 alphaIndex = 0;
        bool bConstantMerchant = isConstantMerchant(tokenId);
        if (bConstantMerchant == false) {
            alphaIndex = selectDwarfType(seed);
        }
        while (true) {
            t = selectTraits(seed, alphaIndex);
            if (mapTraithashToken[getTraitHash(t)] == 0) {
                t.generation = generationOfNft;
                t.isMerchant = (alphaIndex < 5);
                t.cityId = (alphaIndex < 5) ? 0 : cityId; // if Merchant, cityId should be 0 (no city)
                t.alphaIndex = alphaIndex;

                mapTokenTraits[tokenId] = t;
                mapTraithashToken[getTraitHash(t)] = tokenId;

                count_dwarfs[t.alphaIndex < 5 ? 0 : t.alphaIndex - 4]++;
                if (bConstantMerchant == false) {
                    totalDwarfsPerCity--;
                    if (totalDwarfsPerCity == 0) {
                        totalDwarfsPerCity =
                            MAX_DWARFS_CITY[0] + // merchant
                            MAX_DWARFS_CITY[1] + // dwarfsoldier
                            MAX_DWARFS_CITY[2] + // dwarfcapos
                            MAX_DWARFS_CITY[3] + // boss
                            MAX_DWARFS_CITY[4]; // dwarfather
                    }
                }

                return t;
            }
        }
    }

    /**
     * @dev select Dwarf Type Merchant : alphaIndex = 0 ~ 4 Mobster : alphaIndex = 5 ~ 8
     * @param seed the seed to generate random
     * @return alphaIndex the alpha index
     */
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
                (cur_seed & 0xFFFF) % totalDwarfsPerCity <
                (MAX_DWARFS_CITY[4] - count_dwarfs[4]) // checking the dwarfather
            ) {
                return 8;
            } else if (
                (cur_seed & 0xFFFF) % totalDwarfsPerCity <
                (MAX_DWARFS_CITY[3] +
                    MAX_DWARFS_CITY[4] -
                    count_dwarfs[3] -
                    count_dwarfs[4]) // checking the boss
            ) {
                return 7;
            } else if (
                (cur_seed & 0xFFFF) % totalDwarfsPerCity <
                (MAX_DWARFS_CITY[2] +
                    MAX_DWARFS_CITY[3] +
                    MAX_DWARFS_CITY[4] -
                    count_dwarfs[2] -
                    count_dwarfs[3] -
                    count_dwarfs[4]) // checking the dwarfcapos
            ) {
                return 6;
            } else if (
                (cur_seed & 0xFFFF) % totalDwarfsPerCity <
                (MAX_DWARFS_CITY[1] +
                    MAX_DWARFS_CITY[2] +
                    MAX_DWARFS_CITY[3] +
                    MAX_DWARFS_CITY[4] -
                    count_dwarfs[1] -
                    count_dwarfs[2] -
                    count_dwarfs[3] -
                    count_dwarfs[4]) // checking the dwarfsoldier
            ) {
                return 5;
            } else {
                return 0;
            }
        }
    }

    /**
     * @dev selects the species and all of its traits based on the seed value
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
            t = bossTraits[totalBosses];
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
    function getTraitHash(DwarfTrait memory s) internal pure returns (uint256) {
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

    /** READ */
    /**
     * @dev get the token traits details
     * @param tokenId the token id
     * @return DwarfTrait memory
     */
    function getTokenTraits(uint256 tokenId)
        external
        view
        override
        returns (DwarfTrait memory)
    {
        return mapTokenTraits[tokenId];
    }

    /** ADMIN */

    /**
     * @dev called after deployment so that the contract can get random mobster thieves
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
     * @dev updates the number of tokens for sale
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

    /**
     * @dev get the number of tokens in all generate
     * @return _numTokens the number of tokens
     */
    function getGenTokens()
        external
        view
        returns (uint256[] memory _numTokens)
    {
        return MAX_GEN_TOKENS;
    }

    /**
     * @dev set the ETH prices
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

    /**
     * @dev get the ETH prices in all generate
     * @return _prices the ETH prices
     */
    function getMintETHPrices()
        external
        view
        returns (uint256[] memory _prices)
    {
        return MINT_ETH_PRICES;
    }

    /**
     * @dev set the GOD prices
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

    /**
     * @dev get the GOD prices in all generate
     * @return _prices the GOD prices
     */
    function getMintGODPrices()
        external
        view
        returns (uint256[] memory _prices)
    {
        return MINT_GOD_PRICES;
    }

    /**
     * @dev set the ETH percent
     * @param _percent the percent of ETH
     */
    function setEthSoldPercent(uint16 _percent) external onlyOwner {
        MAX_TOKENS_ETH_SOLD = _percent;
    }

    /**
     * @dev get the ETH sold percent
     * @return _percent the percent
     */
    function getEthSoldPercent() external view returns (uint16 _percent) {
        return MAX_TOKENS_ETH_SOLD;
    }

    /**
     * @dev set the traits values
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

    /**
     * @dev get the max traits values
     * @return maxValues the max traits values
     */
    function getMaxTraitValues()
        external
        view
        returns (uint8[] memory maxValues)
    {
        return MAX_TRAITS;
    }

    /**
     * @dev get the max number of dwarfs per city
     * @return the number of dwarfs
     */
    function getMaxDwarfsPerCity() internal view returns (uint32) {
        return
            MAX_DWARFS_CITY[0] + // merchants
            MAX_DWARFS_CITY[1] + // dwarfsolider
            MAX_DWARFS_CITY[2] + // dwarfcapos
            MAX_DWARFS_CITY[3] + // boss
            MAX_DWARFS_CITY[4]; // dwarfather
    }

    /**
     * @dev set the max dwarfs per city
     * @param maxValues the max dwarfs
     */
    function setMaxDwarfsPerCity(uint8[] memory maxValues) external onlyOwner {
        require(
            maxValues.length == MAX_DWARFS_CITY.length,
            "Invalid input parameter"
        );

        totalDwarfsPerCity = 0;
        for (uint8 i = 0; i < maxValues.length; i++) {
            MAX_DWARFS_CITY[i] = maxValues[i];
            totalDwarfsPerCity += MAX_DWARFS_CITY[i];
        }
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
     * @dev set the traits of boss
     * @return traits the boss traits array
     */
    function getBossTraits()
        external
        view
        returns (DwarfTrait[] memory traits)
    {
        return bossTraits;
    }

    /**
     * @dev enables owner to pause / unpause minting
     * @param _paused the flag to pause / unpause
     */
    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    /**
     * @dev Internal function to set the base URI for all token IDs. It is
     * automatically added as a prefix to the value returned in {tokenURI},
     * or to the token ID if {tokenURI} is empty.
     * @param _baseURI the base URI string
     */
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    /**
     * @dev Returns the base URI set via {setBaseURI}. This will be
     * automatically added as a prefix in {tokenURI} to each token's URI, or
     * to the token ID if no specific URI is set for that token ID.
     * @return base URI string
     */
    function getBaseURI() public view returns (string memory) {
        return baseURI;
    }

    /** RENDER */
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
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        IDwarfs_NFT.DwarfTrait memory s = mapTokenTraits[tokenId];
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

        string memory _tokenURI = base64(t);

        // If there is no base URI, return the token URI.
        if (bytes(baseURI).length == 0) {
            return string(abi.encodePacked(_tokenURI, ".json"));
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(baseURI, _tokenURI, ".json"));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenId to the baseURI.
        return string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    }

    // base string for base64 encoding
    string internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /**
     * @dev Convert the bytes to base64 string
     * @param data the bytes. it will be converted to base64 string
     * @return base64 string
     */
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
