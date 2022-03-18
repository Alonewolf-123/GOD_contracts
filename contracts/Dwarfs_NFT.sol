// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./IDwarfs_NFT.sol";
import "./IClan.sol";
import "./GOD.sol";
import "./ERC2981ContractWideRoyalties.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/// @title Dwarfs NFT
/// @author Bounyavong
/// @dev Dwarfs NFT logic is implemented and this is the upgradeable
contract Dwarfs_NFT is
    ERC721Upgradeable,
    OwnableUpgradeable,
    IDwarfs_NFT,
    PausableUpgradeable,
    ERC2981ContractWideRoyalties
{

    // eth prices for mint
    uint256[] public MINT_ETH_PRICES;

    // god prices for mint
    uint256[] public MINT_GOD_PRICES;

    // max number of tokens that can be minted in each phase- 20000 in production
    uint256[] public MAX_GEN_TOKENS;

    // sold amount percent by eth (50%)
    uint16 public MAX_TOKENS_ETH_SOLD;

    // number of dwarfs from casino
    uint16 public MAX_CASINO_MINTS;

    // price for playing casino
    uint256 public CASINO_PRICE;

    // number of cities in each generation status
    uint8[] private MAX_NUM_CITY;

    // number of tokens have been minted so far
    uint32 private minted;

    // mapping from tokenId to a struct containing the token's traits
    mapping(uint32 => ITraits.DwarfTrait) private mapTokenTraits;

    // mapping casino player - time;
    mapping(address => uint80) private mapCasinoplayerTime;

    // reference to the Clan
    IClan private clan;
    // reference to the ITrait
    ITraits private nft_traits;
    // reference to $GOD for burning in mint
    GOD private god;

    // Base URI
    string[] private baseURI;

    // current count of mobsters
    uint256 private count_mobsters;

    // current number of dwarfs of casino play
    uint16 private count_casinoMints;

    // current generation number of NFT
    uint8 private generationOfNft;

    event Mint(
        uint32[] tokenIds,
        ITraits.DwarfTrait[] traits,
        uint256 timestamp
    );
    event MintByOwner(uint32[] tokenIds, uint256 timestamp);
    event MintOfCasino(uint32[] tokenIds, uint256 timestamp);

    /**
     * @dev instantiates contract and rarity tables
     * @param _god the GOD address
     */
    function initialize(address _god, address _traits)
        public
        virtual
        initializer
    {
        __Ownable_init();
        __Pausable_init();
        __ERC721_init("Dwarf NFT", "DWARF");
        god = GOD(_god);
        nft_traits = ITraits(_traits);

        // eth prices for mint
        MINT_ETH_PRICES = [
            0.0012 ether, // ETH price in Gen0
            0.0014 ether, // ETH price in Gen1
            0.0016 ether, // ETH price in Gen2
            0.0018 ether // ETH price in Gen3
        ];

        // god prices for mint
        MINT_GOD_PRICES = [
            0, // GOD price in Gen0
            100000, // GOD price in Gen1
            120000, // GOD price in Gen2
            140000 // GOD price in Gen3
        ];

        // max number of tokens that can be minted in each phase- 20000 in production
        MAX_GEN_TOKENS = [
            8000, // number of tokens in Gen0
            12000, // number of tokens in Gen1
            16000, // number of tokens in Gen2
            20000
        ]; // number of tokens in Gen3

        // sold amount percent by eth (50%)
        MAX_TOKENS_ETH_SOLD = 50;

        MAX_CASINO_MINTS = 50; // max number of mints from casino is 50

        CASINO_PRICE = 1000; // price of casino play is 1000 GOD

        // number of cities in each generation status
        MAX_NUM_CITY = [6, 9, 12, 15];

        // count of mobsters
        count_mobsters = 0;

        // current number of dwarfs of casino
        count_casinoMints = 0;

        // current generation number of NFT
        generationOfNft = 0;
    }

    /// @inheritdoc	ERC165Upgradeable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Upgradeable, ERC2981Base)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /// @notice Allows to set the royalties on the contract
    /// @dev This function in a real contract should be protected with a onlyOwner (or equivalent) modifier
    /// @param recipient the royalties recipient
    /// @param value royalties value (between 0 and 10000)
    function setRoyalties(address recipient, uint256 value) external onlyOwner {
        _setRoyalties(recipient, value);
    }

    /**
     * @dev mint a token by owner
     * @param amount the mint amount
     * @param s the traits array
     */
    function mintByOwner(uint16 amount, ITraits.DwarfTrait[] memory s)
        external
        onlyOwner
    {
        require(s.length == amount, "Invalid parameter");
        uint32[] memory tokenIds = new uint32[](amount);
        for (uint16 i = 0; i < amount; i++) {
            minted++;
            mapTokenTraits[minted] = s[i];
            tokenIds[i] = minted;
            _safeMint(_msgSender(), minted);
        }

        emit MintByOwner(tokenIds, block.timestamp);
    }

    /**
     * @dev mint a token from casino
     */
    function mintOfCasino() external payable whenNotPaused {
        require(tx.origin == _msgSender(), "Only EOA");
        require(
            generationOfNft > 0,
            "Casino mint will be started from Phase 2"
        );
        require(
            count_casinoMints < MAX_CASINO_MINTS,
            "All the casino dwarfs of current generation have been minted already"
        );
        require(
            mapCasinoplayerTime[_msgSender()] + 12 hours >=
                uint80(block.timestamp) ||
                mapCasinoplayerTime[_msgSender()] == 0,
            "You can play the casino in 12 hours"
        );
        god.burn(_msgSender(), CASINO_PRICE);

        mapCasinoplayerTime[_msgSender()] = uint80(block.timestamp);

        uint256 seed = random(block.timestamp);
        if ((seed & 0xFFFF) % 100 > 0) return;

        minted++;
        if (minted > MAX_GEN_TOKENS[generationOfNft] && generationOfNft < 3) {
            generationOfNft++;
            count_casinoMints = 0;
        }
        seed = random(minted);
        generate(minted, seed);

        count_casinoMints++;

        _safeMint(_msgSender(), minted);

        uint32[] memory tokenIds = new uint32[](1);
        tokenIds[0] = minted;
        clan.addManyToClan(tokenIds);
        emit MintOfCasino(tokenIds, block.timestamp);
    }

    /**
     * @dev mint a token - 85% Merchant, 15% Mobsters
     * @param amount the amount of the token
     */
    function mint(uint16 amount) external payable whenNotPaused {
        require(tx.origin == _msgSender(), "Only EOA");
        require(minted + amount <= MAX_GEN_TOKENS[3], "All tokens minted");
        require(amount > 0 && amount <= 10, "Invalid mint amount");

        if (generationOfNft == 0) {
            require(
                minted + amount <= MAX_GEN_TOKENS[generationOfNft],
                "All tokens of generation on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICES[generationOfNft] <= msg.value,
                "Invalid ETH payment amount"
            );
        } else {
            require(
                minted + amount <=
                    MAX_GEN_TOKENS[generationOfNft - 1] +
                        ((MAX_GEN_TOKENS[generationOfNft - 1] -
                            MAX_GEN_TOKENS[generationOfNft - 1]) *
                            MAX_TOKENS_ETH_SOLD) /
                        100,
                "All tokens of generation on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICES[generationOfNft] <= msg.value,
                "Invalid ETH payment amount"
            );
        }

        uint256 totalGodCost = 0;
        for (uint16 i = 0; i < amount; i++) {
            totalGodCost += mintCost(minted + i + 1);
        }
        if (totalGodCost > 0) god.burn(_msgSender(), totalGodCost);

        uint32[] memory tokenIds = new uint32[](amount);
        ITraits.DwarfTrait[] memory traits = new ITraits.DwarfTrait[](amount);
        uint256 seed;

        for (uint16 i = 0; i < amount; i++) {
            minted++;
            if (
                minted > MAX_GEN_TOKENS[generationOfNft] && generationOfNft < 3
            ) {
                generationOfNft++;
                count_casinoMints = 0;
            }
            seed = random(minted);

            generate(minted, seed);

            _safeMint(_msgSender(), minted);
            tokenIds[i] = minted;
            traits[i] = mapTokenTraits[minted];
        }

        clan.addManyToClan(tokenIds);

        emit Mint(tokenIds, traits, block.timestamp);
    }

    /**
     * @dev the calculate the cost of mint by the generating
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
    ) public virtual {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );
        _transfer(from, to, tokenId);
    }

    /**
     * @dev generates traits for a specific token, checking to make sure it's unique
     * @param tokenId the id of the token to generate traits for
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t - a struct of traits for the given token ID
     */
    function generate(uint32 tokenId, uint256 seed)
        internal
        returns (ITraits.DwarfTrait memory t)
    {
        // check the merchant or mobster
        bool _bMerchant = ((count_mobsters ==
            uint256(MAX_NUM_CITY[generationOfNft] * 200)) &&
            (tokenId <= uint32(MAX_GEN_TOKENS[generationOfNft])));

        seed = random(seed);
        _bMerchant = (_bMerchant || (((seed & 0xFFFF) % 100) > 15));

        if (_bMerchant == false) {
            count_mobsters++;
        }

        t = nft_traits.selectTraits(seed, _bMerchant, generationOfNft);

        mapTokenTraits[tokenId] = t;
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
    function getTokenTraits(uint32 tokenId)
        external
        view
        override
        returns (ITraits.DwarfTrait memory)
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
     * @dev set the ETH percent
     * @param _percent the percent of ETH
     */
    function setEthSoldPercent(uint16 _percent) external onlyOwner {
        MAX_TOKENS_ETH_SOLD = _percent;
    }

    /**
     * @dev set the max number of dwarfs from casino
     * @param maxCasinoMints the max dwarfs from casino
     */
    function getMaxCasinoMints(uint16 maxCasinoMints) external onlyOwner {
        MAX_CASINO_MINTS = maxCasinoMints;
    }

    /**
     * @dev enables owner to pause / unpause minting
     * @param _bPaused the flag to pause / unpause
     */
    function setPaused(bool _bPaused) external onlyOwner {
        if (_bPaused) _pause();
        else _unpause();
    }

    /**
     * @dev Internal function to set the base URI for all token IDs. It is
     * automatically added as a prefix to the value returned in {tokenURI},
     * or to the token ID if {tokenURI} is empty.
     * @param _baseURI the base URI string
     */
    function setBaseURI(string memory _baseURI, uint8 _generation)
        external
        onlyOwner
    {
        if (baseURI.length <= _generation) {
            baseURI.push(_baseURI);
        } else {
            baseURI[_generation] = _baseURI;
        }
    }

    /**
     * @dev Internal function to get a hash of an integer
     * @param index the index of the dwarf list
     */
    function getHashString(uint32 index) public pure returns (string memory result) {
        result = string(abi.encodePacked(keccak256(abi.encodePacked(index))));
    }

    /** RENDER */
    /**
     * @dev Returns the token URI. BaseURI will be
     * automatically added as a prefix in {tokenURI} to each token's URI, or
     * to the token ID if no specific URI is set for that token ID.
     * @param tokenId the token id
     * @return token URI string
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory _tokenURI = getHashString(
            mapTokenTraits[uint32(tokenId)].index
        );

        uint8 _generation = mapTokenTraits[uint32(tokenId)].generation;

        // If there is no base URI, return the token URI.
        if (bytes(baseURI[_generation]).length == 0) {
            return string(abi.encodePacked(_tokenURI, ".json"));
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return
                string(
                    abi.encodePacked(baseURI[_generation], _tokenURI, ".json")
                );
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenId to the baseURI.
        return
            string(
                abi.encodePacked(
                    baseURI[_generation],
                    abi.encodePacked(tokenId),
                    ".json"
                )
            );
    }
}
