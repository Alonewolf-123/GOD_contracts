// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./Pausable.sol";
import "./Dwarfs_NFT.sol";
import "./GOD.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

contract Clan is Initializable, Ownable, IERC721ReceiverUpgradeable, Pausable {
    uint8 private MAX_NUM_CITY = 15;

    // struct to store a stake's token, owner, and earning values
    struct Stake {
        uint16 tokenId;
        uint80 timestamp;
        address owner;
    }

    // struct to store a invest god
    struct InvestGods {
        uint256 value;
        uint80 timestamp;
    }

    event TokenStaked(address owner, uint256 tokenId, uint256 value);
    event MerchantClaimed(uint256 tokenId, uint256 earned);
    event MobsterClaimed(uint256 tokenId, uint256 earned);

    // reference to the Dwarfs_NFT NFT contract
    Dwarfs_NFT dwarfs_nft;

    // reference to the $GOD contract for minting $GOD earnings
    GOD god;

    mapping(uint8 => Stake[]) private cities;
    mapping(uint16 => bool) private existingCombinations;
    mapping(uint16 => InvestGods[]) private gods;
    mapping(uint16 => uint256) private mobsterRewards;

    // merchant earn 1% of investment of $GOD per day
    uint256 private constant DAILY_GOD_RATE = 1;

    // riskygame merchant must have 2 days worth of $GOD to unstake or else it's too cold
    uint256 private constant MIN_TO_EXIT_RISKY = 2 days;

    // mobsters take a 15% tax on all $GOD claimed
    uint256 private constant GOD_CLAIM_TAX_PERCENTAGE = 15;

    // casino vault take a 5% tax on all $GOD claimed
    uint256 private constant CASINO_VAULT_PERCENTAGE = 5;

    // there will only ever be (roughly) 2.4 billion $GOD earned through staking
    uint256 private constant MAXIMUM_GLOBAL_GOD = 2400000000 ether;

    // default god amount
    uint256 private constant DEFAULT_GODS = 100000 ether;

    // default god amount of casino
    uint256 private constant DEFAULT_GODS_CASINO = 1000 ether;

    // amount of $GOD earned so far
    uint256 private totalGodEarned;

    // amount of casino vault $GOD
    uint256 private casinoVault;

    // profit of dwarfather
    uint256[] private mobsterProfits = [29, 14, 7, 4];

    /**
     * @param _dwarfs_nft reference to the Dwarfs_NFT NFT contract
     * @param _god reference to the $GOD token
     */
    // constructor(address _dwarfs_nft, address _god) {
    function initialize(address _dwarfs_nft, address _god)
        public
        virtual
        initializer
    {
        dwarfs_nft = Dwarfs_NFT(_dwarfs_nft);
        god = GOD(_god);
    }

    /** STAKING */

    /**
     * adds Merchant and Mobsters to the Clan and Pack
     * @param account the address of the staker
     * @param tokenIds the IDs of the Merchant and Mobsters to stake
     */
    function addManyToClan(address account, uint16[] calldata tokenIds)
        external
    {
        require(
            account == _msgSender() || _msgSender() == address(dwarfs_nft),
            "DONT GIVE YOUR TOKENS AWAY"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(tokenIds[i] > 0, "Invalid token id");
            require(existingCombinations[tokenIds[i]] == false, "Existed token");
            
            if (_msgSender() != address(dwarfs_nft)) {
                // dont do this step if its a mint + stake
                require(
                    dwarfs_nft.ownerOf(tokenIds[i]) == _msgSender(),
                    "AINT YO TOKEN"
                );
            }
            if (_msgSender() == address(dwarfs_nft)) {
                require(
                    isMerchant(tokenIds[i]) == false,
                    "Can not add the merchant directly"
                );
            }

            _addToCity(account, tokenIds[i]);
        }
    }

    /**
     * adds a single token to the city
     * @param account the address of the staker
     * @param tokenId the ID of the Merchant to add to the Clan
     */
    function _addToCity(address account, uint16 tokenId)
        internal
        whenNotPaused
    {
        uint8 cityId = getCityId(tokenId);
        existingCombinations[tokenId] = true;
        gods[tokenId].push(
            InvestGods({
                value: getGeneration(tokenId) == 0
                    ? DEFAULT_GODS
                    : DEFAULT_GODS / 2,
                timestamp: uint80(block.timestamp)
            })
        );

        cities[cityId].push(
            Stake({
                owner: account,
                tokenId: tokenId,
                timestamp: uint80(block.timestamp)
            })
        );

        emit TokenStaked(account, tokenId, block.timestamp);
    }

    /**
     * Invest GODs
     */
    function investGods(uint16 tokenId, uint256 godAmount) external {
        require(
            dwarfs_nft.ownerOf(tokenId) == _msgSender() && godAmount > 0,
            "AINT YO TOKEN"
        );

        god.burn(_msgSender(), godAmount);
        gods[tokenId].push(
            InvestGods({
                value: gods[tokenId].length > 0
                    ? godAmount + gods[tokenId][gods[tokenId].length - 1].value
                    : godAmount,
                timestamp: uint80(block.timestamp)
            })
        );
    }

    /**
     * checks if a token is a merchant or mobster
     * @param tokenId the ID of the token to check
     * @return merchant - whether or not a token is a merchant
     */
    function isMerchant(uint256 tokenId) public view returns (bool merchant) {
        IDwarfs_NFT.DwarfTrait memory t = dwarfs_nft.getTokenTraits(tokenId);
        return t.isMerchant;
    }

    /**
     * get the city id of a token
     * @param tokenId the ID of the token to get the city id
     * @return cityId - city id of merchant
     */
    function getCityId(uint256 tokenId) public view returns (uint8 cityId) {
        IDwarfs_NFT.DwarfTrait memory t = dwarfs_nft.getTokenTraits(tokenId);
        return t.cityId;
    }

    /**
     * get the alpha of a token
     * @param tokenId the ID of the token to get the alpha
     * @return alpha - alpha of merchant
     */
    function getAlpha(uint256 tokenId) public view returns (uint8 alpha) {
        IDwarfs_NFT.DwarfTrait memory t = dwarfs_nft.getTokenTraits(tokenId);
        return t.alphaIndex;
    }

    /**
     * get the generation of a token
     * @param tokenId the ID of the token to get the alpha
     * @return generation - alpha of merchant
     */
    function getGeneration(uint256 tokenId)
        public
        view
        returns (uint8 generation)
    {
        IDwarfs_NFT.DwarfTrait memory t = dwarfs_nft.getTokenTraits(tokenId);
        return t.generation;
    }

    /** CLAIMING / RISKY */
    /**
     * realize $GOD earnings and optionally unstake tokens from the Clan (Cities)
     * to unstake a Merchant it will require it has 2 days worth of $GOD unclaimed
     * @param tokenIds the IDs of the tokens to claim earnings from
     */
    function claimManyFromClan(uint16[] calldata tokenIds, bool isRisky)
        external
        whenNotPaused
    {
        uint256 owed = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                existingCombinations[tokenIds[i]] == true,
                "No existed token"
            );

            if (isMerchant(tokenIds[i]))
                owed += _claimMerchantFromCity(tokenIds[i], isRisky);
            else owed += _claimMobsterFromCity(tokenIds[i]);
        }

        if (owed == 0) return;

        totalGodEarned += owed;
        god.mint(_msgSender(), owed);
    }

    /**
     * realize $GOD earnings for a single Merchant and optionally unstake it
     * if not unstaking, pay a 20% tax to the staked Mobsters
     * if unstaking, there is a 50% chance all $GOD is stolen
     * @param tokenId the ID of the Merchant to claim earnings from
     * @return owed - the amount of $GOD earned
     */
    function _claimMerchantFromCity(uint16 tokenId, bool isRisky)
        internal
        returns (uint256 owed)
    {
        uint8 cityId = getCityId(tokenId);
        Stake memory stake = cities[cityId][tokenId];
        require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
        require(totalGodEarned < MAXIMUM_GLOBAL_GOD, "LIMIT GOD ERROR");
        if (isRisky == true) {
            require(
                block.timestamp - stake.timestamp < MIN_TO_EXIT_RISKY,
                "LIMIT EXIT TIME 2DAYS"
            );
        }

        uint80 stake_timestamp = stake.timestamp;
        uint256 invest_value = 0;
        uint80 invest_timestamp = 0;
        for (uint256 i = 0; i < gods[tokenId].length; i++) {
            invest_timestamp = gods[tokenId][i].timestamp;
            if (i == gods[tokenId].length - 1) {
                invest_timestamp = uint80(block.timestamp);
                invest_value = gods[tokenId][i].value;
            } else {
                invest_value = gods[tokenId][i - 1].value;
            }

            if (invest_timestamp > stake_timestamp) {
                owed +=
                    (((invest_timestamp - stake.timestamp) *
                        invest_value *
                        DAILY_GOD_RATE) / 100) /
                    1 days;

                stake_timestamp = invest_timestamp;
            }
        }

        uint256 m_mobsterRewards = 0;
        if (isRisky == true) {
            // risky game
            if (random(tokenId) & 1 == 1) {
                // 50%
                m_mobsterRewards += owed;
                owed = 0;
            }
        } else {
            m_mobsterRewards += (owed * GOD_CLAIM_TAX_PERCENTAGE) / 100;
            casinoVault += (owed * CASINO_VAULT_PERCENTAGE) / 100;
            owed =
                (owed *
                    (100 -
                        GOD_CLAIM_TAX_PERCENTAGE -
                        CASINO_VAULT_PERCENTAGE)) /
                100;
            distributeToMobsters(cityId, m_mobsterRewards);
        }

        cities[cityId][tokenId].owner = _msgSender();
        cities[cityId][tokenId].tokenId = uint16(tokenId);
        cities[cityId][tokenId].timestamp = uint80(block.timestamp);

        emit MerchantClaimed(tokenId, owed);
    }

    function distributeToMobsters(uint8 cityId, uint256 amount) internal {
        uint16[] memory mobsters = getMobstersByCityId(cityId);
        for (uint16 i = 0; i < mobsters.length; i++) {
            mobsterRewards[mobsters[i]] =
                (amount * mobsterProfits[getAlpha(mobsters[i]) - 5]) /
                1000;
        }
    }

    /**
     * realize $GOD earnings for a single Mobster and optionally unstake it
     * Mobsters earn $GOD proportional to their Alpha rank
     * @param tokenId the ID of the Mobster to claim earnings from
     * @return owed - the amount of $GOD earned
     */
    function _claimMobsterFromCity(uint16 tokenId)
        internal
        returns (uint256 owed)
    {
        require(dwarfs_nft.ownerOf(tokenId) == _msgSender(), "Invalid Owner");

        owed = mobsterRewards[tokenId];
        mobsterRewards[tokenId] = 0;

        // Not implemented yet
        emit MobsterClaimed(tokenId, owed);
    }

    /**
     * realize $GOD earnings for a single Mobster and optionally unstake it
     * Mobsters earn $GOD proportional to their Alpha rank
     * @param tokenId the ID of the merchants to claim earnings from casinos
     */
    function claimFromCasino(uint16 tokenId) external whenNotPaused {
        require(dwarfs_nft.ownerOf(tokenId) == _msgSender(), "Invalid Owner");

        uint256 owed = 0;
        god.burn(_msgSender(), DEFAULT_GODS_CASINO);

        casinoVault += DEFAULT_GODS_CASINO;
        if ((random(tokenId) & 0xFFFF) % 100 == 0) {
            // 1%
            owed = casinoVault;
            casinoVault = 0;
        } else {
            owed = 0;
            // burn betting amount from the mobsters
        }

        if (owed == 0) return;
        god.mint(_msgSender(), owed);
    }

    /** ADMIN */
    /**
     * enables owner to pause / unpause minting
     */
    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    function getMaxNumCity() external view returns (uint8) {
        return MAX_NUM_CITY;
    }

    function setMaxNumCity(uint8 maxCity) external onlyOwner {
        MAX_NUM_CITY = maxCity;
    }

    /* Get the available city id */
    function getAvailableCity() internal view returns (uint8) {
        for (uint8 i = 0; i < MAX_NUM_CITY; i++) {
            if (cities[i].length < 200) {
                return i;
            }
        }

        return 0;
    }

    /**
     * Get the mobster tokenIds by the city Id and alpha
     */
    function getMobstersByCityId(uint8 cityId)
        public
        view
        returns (uint16[] memory)
    {
        uint16[] memory numMobsters = getNumMobstersByCityId(cityId);
        uint16[] memory tokenIds = new uint16[](
            numMobsters[0] + numMobsters[1] + numMobsters[2] + numMobsters[3]
        );
        uint16 index = 0;
        for (uint256 i = 0; i < cities[cityId].length; i++) {
            if (isMerchant(cities[cityId][i].tokenId) == false) {
                tokenIds[index] = cities[cityId][i].tokenId;
                index++;
            }
        }

        return tokenIds;
    }

    /* Get the number of boss in city */
    function getNumMobstersByCityId(uint8 cityId)
        public
        view
        returns (uint16[] memory)
    {
        uint16[] memory res = new uint16[](4);
        uint8 alpha = 0;
        for (uint16 i = 0; i < cities[cityId].length; i++) {
            alpha = getAlpha(cities[cityId][i].tokenId);
            if (alpha >= 5 && alpha <= 8) {
                res[alpha - 5]++;
            }
        }

        return res;
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

    function onERC721Received(
        address,
        address from,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        require(from == address(0x0), "Cannot send tokens to Clan directly");
        return IERC721ReceiverUpgradeable.onERC721Received.selector;
    }
}
