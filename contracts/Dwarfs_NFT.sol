// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./IClan.sol";
import "./IGOD.sol";
import "./ERC2981ContractWideRoyalties.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/// @title Dwarfs NFT
/// @author Bounyavong
/// @dev Dwarfs NFT logic is implemented and this is the upgradeable
contract Dwarfs_NFT is
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    ERC2981ContractWideRoyalties
{
    // eth prices for mint
    uint256[] public MINT_ETH_PRICES;

    // god prices for mint
    uint256[] public MINT_GOD_PRICES;

    // max number of tokens that can be minted in each phase- 20000 in production
    uint32[] public MAX_GEN_TOKENS;

    struct ContractInfo {
        // sold amount percent by eth (50%)
        uint32 MAX_TOKENS_ETH_SOLD;
        // number of dwarfs from casino
        uint32 MAX_CASINO_MINTS;
        // current count of mobsters
        uint32 count_mobsters;
        // current generation number of NFT
        uint32 generationOfNft;
    }
    ContractInfo public contractInfo;

    // price for playing casino
    uint256 public CASINO_PRICE;

    // number of cities in each generation status
    uint32[] public MAX_NUM_CITY;

    // number of tokens have been minted so far
    uint256 public minted;

    // mapping from tokenId to a struct containing the token's traits
    mapping(uint256 => ITraits.DwarfTrait) private mapTokenTraits;

    // mapping casino player's tokenId - time;
    mapping(uint256 => uint256) private mapCasinoplayerTime;

    // reference to the Clan
    IClan public clan;
    // reference to the ITrait
    ITraits public nft_traits;
    // reference to $GOD for burning in mint
    IGOD public god;

    // Base URI
    string[] private baseURI;

    // current number of dwarfs of casino play
    uint32[] public count_casinoMints;

    event Mint(uint256 lastTokenId, uint256 timestamp);

    struct AirdropInfo {
        uint64 countAirdropAddresses;
        uint64 MAX_AIRDROP_AMOUNT;
        uint128 lockTime;
    }
    AirdropInfo public airdropInfo;

    mapping(address => bool) mapAirdropAddresses;
    mapping(address => uint256) mapAirdropaddressMinttime;

    event MintOfCasino(uint256 tokenId, uint256 timestamp);

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
        god = IGOD(_god);
        nft_traits = ITraits(_traits);

        // eth prices for mint
        MINT_ETH_PRICES = [
            0.00012 ether, // ETH price in Gen0
            0.00014 ether, // ETH price in Gen1
            0.00016 ether, // ETH price in Gen2
            0.00018 ether // ETH price in Gen3
        ];

        // god prices for mint
        MINT_GOD_PRICES = [
            80000 ether, // GOD price in Gen0
            100000 ether, // GOD price in Gen1
            120000 ether, // GOD price in Gen2
            140000 ether // GOD price in Gen3
        ];

        // max number of tokens that can be minted in each phase- 20000 in production
        MAX_GEN_TOKENS = [
            8000, // number of tokens in Gen0
            12000, // number of tokens in Gen1
            16000, // number of tokens in Gen2
            20000
        ]; // number of tokens in Gen3

        // sold amount percent by eth (50%)
        contractInfo.MAX_TOKENS_ETH_SOLD = 50;

        contractInfo.MAX_CASINO_MINTS = 500; // max number of mints from casino is 500

        CASINO_PRICE = 1000 ether; // price of casino play is 1000 GOD

        // number of cities in each generation status
        MAX_NUM_CITY = [6, 9, 12, 15];

        // current number of dwarfs of casino
        count_casinoMints = new uint32[](4);

        // init the base URIs
        baseURI = new string[](4);

        // 1200 NFTs will be mint for free
        airdropInfo.MAX_AIRDROP_AMOUNT = 1200;
        // Airdrop NFTs will be locked for 6 days;
        airdropInfo.lockTime = 6 days;

        _pause();
    }

    /// @inheritdoc	ERC165Upgradeable
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721EnumerableUpgradeable, ERC2981Base)
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
     * @param traits the traits array
     */
    function mintByOwner(uint256 amount, ITraits.DwarfTrait[] calldata traits)
        external
        onlyOwner
    {
        require(traits.length == amount, "Invalid parameter");
        uint256[] memory tokenIds = new uint256[](amount);
        uint256 tokenId = minted;
        for (uint256 i = 0; i < amount; i++) {
            tokenId++;
            mapTokenTraits[tokenId] = traits[i];
            tokenIds[i] = tokenId;
            _safeMint(_msgSender(), tokenId);
        }
        minted = tokenId;
    }

    /**
     * @dev mint a token
     */
    function _mintOneToken() internal {
        minted++;
        if (minted >= MAX_GEN_TOKENS[contractInfo.generationOfNft]) {
            contractInfo.generationOfNft++;
            _pause();
        }
        uint256 _countMerchant;
        uint256 _countMobster;
        (_countMerchant, _countMobster) = generate(1);
        ITraits.DwarfTrait[] memory traits = nft_traits.selectTraits(
            contractInfo.generationOfNft,
            _countMerchant,
            _countMobster
        );
        mapTokenTraits[minted] = traits[0];

        count_casinoMints[contractInfo.generationOfNft]++;

        _safeMint(_msgSender(), minted);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = minted;
        clan.addManyToClan(tokenIds, traits);
    }

    /**
     * @dev mint a token from casino
     * @param tokenId that you have. Only one of NFT owners can play the casino
     */
    function mintOfCasino(uint256 tokenId) external whenNotPaused {
        require(tx.origin == _msgSender(), "Only EOA");
        require(contractInfo.generationOfNft > 0, "START_PHASE_2");
        require(
            count_casinoMints[contractInfo.generationOfNft] <
                contractInfo.MAX_CASINO_MINTS,
            "SOLD_OUT_CASINO"
        );
        require(ownerOf(tokenId) == _msgSender(), "NOT_NFT_OWNER");
        require(
            mapCasinoplayerTime[tokenId] + 12 hours <= block.timestamp ||
                mapCasinoplayerTime[tokenId] == 0,
            "PLAY_IN_12_HOURS"
        );
        god.burn(_msgSender(), CASINO_PRICE);

        mapCasinoplayerTime[tokenId] = block.timestamp;

        uint256 seed = random(block.timestamp);
        if (seed % 100 > 0) return;

        _mintOneToken();

        emit MintOfCasino(minted, block.timestamp);
    }

    /**
     * @dev airdrop mint a token - 85% Merchant, 15% Mobsters
     */
    function airdropMint() external whenNotPaused {
        require(tx.origin == _msgSender(), "Only EOA");
        require(minted < airdropInfo.MAX_AIRDROP_AMOUNT, "SOLD_OUT_AIRDROP");
        require(
            mapAirdropAddresses[_msgSender()] == true,
            "NOT_AIRDROP_ADDRESS"
        );
        require(
            mapAirdropaddressMinttime[_msgSender()] == 0,
            "ALREADY_AIRDROPED"
        );
        _mintOneToken();
        mapAirdropaddressMinttime[_msgSender()] = block.timestamp;
    }

    /**
     * @dev airdrop mint a token with $GOD - 85% Merchant, 15% Mobsters
     */
    function airdropMintWithGod() external whenNotPaused {
        require(tx.origin == _msgSender(), "Only EOA");
        require(
            minted < airdropInfo.MAX_AIRDROP_AMOUNT * 2,
            "SOLD_OUT_AIRDROP"
        );
        require(
            mapAirdropAddresses[_msgSender()] == true,
            "NOT_AIRDROP_ADDRESS"
        );
        god.burn(_msgSender(), MINT_GOD_PRICES[contractInfo.generationOfNft]);
        _mintOneToken();
        mapAirdropaddressMinttime[_msgSender()] = block.timestamp;
    }

    /**
     * @dev mint a token - 85% Merchant, 15% Mobsters
     * @param amount the amount of the token
     */
    function mint(uint256 amount) external payable whenNotPaused {
        require(tx.origin == _msgSender(), "Only EOA");
        require(
            minted + amount <= MAX_GEN_TOKENS[contractInfo.generationOfNft],
            "SOLD_OUT_OF_GEN"
        );
        require(amount > 0 && amount <= 10, "INVALID_AMOUNT");

        uint256[] memory tokenIds = new uint256[](amount);

        uint256 _countMerchant;
        uint256 _countMobster;
        (_countMerchant, _countMobster) = generate(amount);
        ITraits.DwarfTrait[] memory traits = nft_traits.selectTraits(
            contractInfo.generationOfNft,
            _countMerchant,
            _countMobster
        );
        uint256 tokenId = minted;
        uint256 totalGodCost = 0;
        for (uint256 i = 0; i < amount; i++) {
            tokenId++;
            _safeMint(_msgSender(), tokenId);
            tokenIds[i] = tokenId;
            mapTokenTraits[tokenId] = traits[i];
            totalGodCost += mintCost(tokenId);
        }
        require(
            (amount -
                totalGodCost /
                MINT_GOD_PRICES[contractInfo.generationOfNft]) *
                MINT_ETH_PRICES[contractInfo.generationOfNft] <=
                msg.value,
            "INVALID_ETH_AMOUNT"
        );
        if (totalGodCost > 0) god.burn(_msgSender(), totalGodCost);

        minted = tokenId;
        if (minted >= MAX_GEN_TOKENS[contractInfo.generationOfNft]) {
            contractInfo.generationOfNft++;
            _pause();
        }

        clan.addManyToClan(tokenIds, traits);

        emit Mint(minted, block.timestamp);
    }

    /**
     * @dev the calculate the cost of mint by the generating
     * @param tokenId the ID to check the cost of to mint
     * @return the GOD cost of the given token ID
     */
    function mintCost(uint256 tokenId) public view returns (uint256) {
        if (contractInfo.generationOfNft == 0) return 0;
        else if (
            tokenId <=
            MAX_GEN_TOKENS[contractInfo.generationOfNft - 1] +
                ((MAX_GEN_TOKENS[contractInfo.generationOfNft] -
                    MAX_GEN_TOKENS[contractInfo.generationOfNft - 1]) *
                    contractInfo.MAX_TOKENS_ETH_SOLD) /
                100
        ) return 0;
        else return MINT_GOD_PRICES[contractInfo.generationOfNft];
    }

    /**
     * @dev generates traits for a specific token, checking to make sure it's unique
     * @param amount count of mint tokens
     * @return countMerchant count of Merchant
     * @return countMobster count of Mobster
     */
    function generate(uint256 amount)
        internal
        returns (uint32 countMerchant, uint32 countMobster)
    {
        bool _bMerchant;
        uint256 seed = random(minted);
        uint256 tokenId = minted;
        uint256 count_mobsters = contractInfo.count_mobsters;
        for (uint256 i = 0; i < amount; i++) {
            tokenId++;
            _bMerchant = ((count_mobsters ==
                MAX_NUM_CITY[contractInfo.generationOfNft] * 200) &&
                (tokenId <= MAX_GEN_TOKENS[contractInfo.generationOfNft]));

            _bMerchant = (_bMerchant || (((seed & 0xFFFF) % 100) > 15));

            if (_bMerchant == false) {
                countMobster++;
                count_mobsters++;
            } else {
                countMerchant++;
            }
            seed >>= 8;
        }
        contractInfo.count_mobsters = uint32(count_mobsters);
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
        returns (ITraits.DwarfTrait memory)
    {
        return mapTokenTraits[tokenId];
    }

    /**
     * @dev get the token traits details
     * @param tokenIds the token ids
     * @return traits DwarfTrait[] memory
     */
    function getBatchTokenTraits(uint256[] calldata tokenIds)
        external
        view
        returns (ITraits.DwarfTrait[] memory traits)
    {
        traits = new ITraits.DwarfTrait[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            traits[i] = mapTokenTraits[tokenIds[i]];
        }
    }

    /** ADMIN */

    /**
     * @dev called after deployment
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
     * @param _generation the generation of the NFT
     */
    function setGenTokens(uint256 _genNumTokens, uint32 _generation)
        external
        onlyOwner
    {
        if (MAX_GEN_TOKENS.length <= _generation) {
            MAX_GEN_TOKENS.push(uint32(_genNumTokens));
        } else {
            MAX_GEN_TOKENS[_generation] = uint32(_genNumTokens);
        }
    }

    /**
     * @dev set the ETH prices
     * @param _price the prices array
     * @param _generation the generation of the NFT
     */
    function setMintETHPrice(uint256 _price, uint32 _generation)
        external
        onlyOwner
    {
        if (MINT_ETH_PRICES.length <= _generation) {
            MINT_ETH_PRICES.push(_price);
        } else {
            MINT_ETH_PRICES[_generation] = _price;
        }
    }

    /**
     * @dev set the GOD prices
     * @param _price the prices array
     * @param _generation the generation of the NFT
     */
    function setMintGODPrice(uint256 _price, uint32 _generation)
        external
        onlyOwner
    {
        if (MINT_GOD_PRICES.length <= _generation) {
            MINT_GOD_PRICES.push(_price);
        } else {
            MINT_GOD_PRICES[_generation] = _price;
        }
    }

    /**
     * @dev set the ETH percent
     * @param _percent the percent of ETH
     */
    function setEthSoldPercent(uint32 _percent) external onlyOwner {
        contractInfo.MAX_TOKENS_ETH_SOLD = _percent;
    }

    /**
     * @dev set the max number of dwarfs from casino
     * @param maxCasinoMints the max dwarfs from casino
     */
    function setMaxCasinoMints(uint32 maxCasinoMints) external onlyOwner {
        contractInfo.MAX_CASINO_MINTS = maxCasinoMints;
    }

    /**
     * @dev set the max number of dwarfs from casino
     * @param _casinoPrice the max dwarfs from casino
     */
    function setCasinoPrice(uint256 _casinoPrice) external onlyOwner {
        CASINO_PRICE = _casinoPrice;
    }

    /**
     * @dev set the generation of NFT
     * @param _generation the generation of nft
     */
    function setGenerationOfNFT(uint32 _generation) external onlyOwner {
        contractInfo.generationOfNft = _generation;
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
     * @param _myBaseUri the base URI string
     * @param _generation the generation of the NFT
     */
    function setBaseURI(string memory _myBaseUri, uint32 _generation)
        external
        onlyOwner
    {
        if (baseURI.length <= _generation) {
            baseURI.push(_myBaseUri);
        } else {
            baseURI[_generation] = _myBaseUri;
        }
    }

    /**
     * @dev add airdrop addresses
     * @param _airdropAddresses the addresses for Airdrop
     */
    function addAirdropAddresses(address[] calldata _airdropAddresses)
        external
        onlyOwner
    {
        require(
            airdropInfo.countAirdropAddresses + _airdropAddresses.length <=
                airdropInfo.MAX_AIRDROP_AMOUNT,
            "OUT_AIRDROP_COUNT"
        );
        for (uint256 i = 0; i < _airdropAddresses.length; i++) {
            mapAirdropAddresses[_airdropAddresses[i]] = true;
        }
        airdropInfo.countAirdropAddresses += uint64(_airdropAddresses.length);
    }

    /**
     * @dev remove airdrop addresses
     * @param _airdropAddresses the addresses for Airdrop
     */
    function removeAirdropAddresses(address[] calldata _airdropAddresses)
        external
        onlyOwner
    {
        require(
            airdropInfo.countAirdropAddresses >= _airdropAddresses.length,
            "OUT_AIRDROP_COUNT"
        );
        for (uint256 i = 0; i < _airdropAddresses.length; i++) {
            require(mapAirdropAddresses[_airdropAddresses[i]] == true, "NO_AIRDROP_ADDRESS");
            mapAirdropAddresses[_airdropAddresses[i]] = false;
        }
        airdropInfo.countAirdropAddresses -= uint64(_airdropAddresses.length);
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

        uint256 _generation = mapTokenTraits[tokenId].generation;

        // If there is no base URI, return the token URI.
        if (bytes(baseURI[_generation]).length == 0) {
            return
                string(
                    abi.encodePacked(mapTokenTraits[tokenId].index, ".json")
                );
        }

        return
            string(
                abi.encodePacked(
                    baseURI[_generation],
                    mapTokenTraits[tokenId].index,
                    ".json"
                )
            );
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );

        // Hardcode the airdop tokens are locked for LOCK duration
        if (mapAirdropAddresses[from] == true) {
            require(
                mapAirdropaddressMinttime[from] + airdropInfo.lockTime <
                    block.timestamp,
                "LOCKED_TOKEN"
            );
        }

        _transfer(from, to, tokenId);
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: transfer caller is not owner nor approved"
        );

        // Hardcode the airdop tokens are locked for LOCK duration
        if (mapAirdropAddresses[from] == true) {
            require(
                mapAirdropaddressMinttime[from] + airdropInfo.lockTime <
                    block.timestamp,
                "LOCKED_TOKEN"
            );
        }

        _safeTransfer(from, to, tokenId, _data);
    }

    /** UTILITY */

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
