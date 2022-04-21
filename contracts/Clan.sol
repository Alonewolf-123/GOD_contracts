// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./IDwarfs_NFT.sol";
import "./IGOD.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

/// @title Clan
/// @author Bounyavong
/// @dev Clan logic is implemented and this is the upgradeable
contract Clan is OwnableUpgradeable, PausableUpgradeable {
    // struct to store a token information
    struct TokenInfo {
        uint32 tokenId;
        uint32 cityId;
        uint32 level;
        uint128 lastInvestedTime;
        uint256 availableBalance;
        uint256 currentInvestedAmount;
    }

    // event when token invested
    event TokenInvested(
        uint32 tokenId,
        uint128 lastInvestedTime,
        uint256 investedAmount
    );

    // reference to the Dwarfs_NFT NFT contract
    IDwarfs_NFT public dwarfs_nft;

    // reference to the $GOD contract for minting $GOD earnings
    IGOD public god;

    // token information map
    mapping(uint256 => TokenInfo) public mapTokenInfo;

    // map of mobster IDs for cityId
    mapping(uint256 => uint32[]) public mapCityMobsters;

    // map of mobster unaccounted GOD for cityId
    mapping(uint256 => uint256) public mapCityTax;

    // map of merchant count for cityId
    mapping(uint256 => uint256) public mapCityMerchantCount;

    struct ContractInfo {
        // total number of tokens in the clan
        uint32 totalNumberOfTokens;
        // max merchant count for a city
        uint32 MAX_MERCHANT_COUNT;
        // merchant earn 1% of investment of $GOD per day
        uint32 DAILY_GOD_RATE;
        // mobsters take 15% on all $GOD claimed
        uint32 TAX_PERCENT;
        // playing merchant game enabled
        uint32 bMerchantGamePlaying;
        // the last cityID in the clan
        uint32 lastCityID;
    }
    ContractInfo public contractInfo;

    // there will only ever be (roughly) 2.4 billion $GOD earned through staking
    uint256 public MAXIMUM_GLOBAL_GOD;

    // initial Balance of a new Merchant
    uint256[] public INITIAL_GOD_AMOUNT;

    // minimum GOD invested amount
    uint256 public MIN_INVESTED_AMOUNT;

    // amount of $GOD earned so far
    uint256 public remainingGodAmount;

    // profit percent of each mobster; x 0.1 %
    uint32[] public mobsterProfitPercent;

    event ClaimManyFromClan(
        uint256[] tokenIds,
        uint256 amount,
        uint256 timestamp
    );

    /**
     * @dev initialize function
     * @param _dwarfs_nft reference to the Dwarfs_NFT NFT contract
     * @param _god reference to the $GOD token
     */
    function initialize(address _dwarfs_nft, address _god)
        public
        virtual
        initializer
    {
        __Ownable_init();
        __Pausable_init();
        dwarfs_nft = IDwarfs_NFT(_dwarfs_nft);
        god = IGOD(_god);

        // merchant earn 1% of investment of $GOD per day
        contractInfo.DAILY_GOD_RATE = 1;

        // mobsters take 20% on all $GOD claimed
        contractInfo.TAX_PERCENT = 20;

        // there will only ever be (roughly) 2.4 billion $GOD earned through staking
        MAXIMUM_GLOBAL_GOD = 3000000000 ether;

        // initial Balance of a new Merchant
        INITIAL_GOD_AMOUNT = [
            100000 ether,
            50000 ether,
            50000 ether,
            50000 ether
        ];

        // minimum GOD invested amount
        MIN_INVESTED_AMOUNT = 1000 ether;

        // amount of $GOD earned so far
        remainingGodAmount = MAXIMUM_GLOBAL_GOD;

        // profit percent of each mobster; x 0.1 %
        mobsterProfitPercent = [4, 7, 14, 29];

        // playing merchant game enabled
        contractInfo.bMerchantGamePlaying = 1;

        contractInfo.MAX_MERCHANT_COUNT = 1200;

        contractInfo.lastCityID = 1;

        _pause();
    }

    /** VIEW */

    /**
     * @dev get the Merchant Ids of the selected city
     * @param _cityId the Id of the city
     */
    function getMerchantIdsOfCity(uint256 _cityId)
        external
        view
        returns (uint256[] memory)
    {
        require(mapCityMerchantCount[_cityId] > 0, "NO_MERCHANT_IN_CITY");

        uint256[] memory tokenIds = new uint256[](
            mapCityMerchantCount[_cityId]
        );
        uint256 count = 0;
        for (uint256 i = 1; i <= contractInfo.totalNumberOfTokens; i++) {
            if (
                mapTokenInfo[i].level < 5 && mapTokenInfo[i].cityId == _cityId
            ) {
                tokenIds[count] = i;
                count++;
            }
        }

        return tokenIds;
    }

    /**
     * @dev get the current information of the selected tokens
     * @param tokenIds the IDs of the tokens
     */
    function getBatchTokenInfo(uint256[] calldata tokenIds)
        external
        view
        returns (TokenInfo[] memory)
    {
        TokenInfo[] memory tokenInfos = new TokenInfo[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            tokenInfos[i] = mapTokenInfo[tokenIds[i]];
        }

        return tokenInfos;
    }

    /**
     * @dev get balance of a token
     * @param tokenId the Id of a token
     * @return tokenBalance the balance of the token
     */
    function getTokenBalance(uint256 tokenId)
        public
        view
        returns (uint256 tokenBalance)
    {
        if (mapTokenInfo[tokenId].level < 5) {
            tokenBalance = calcMerchantBalance(tokenId);
        } else {
            tokenBalance = calcMobsterBalance(tokenId);
        }
    }

    /**
     * @dev get balance of a token
     * @param tokenIds the Ids of tokens
     * @return tokenBalances
     */
    function getBatchTokenBalances(uint256[] calldata tokenIds)
        external
        view
        returns (uint256[] memory tokenBalances)
    {
        tokenBalances = new uint256[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            tokenBalances[i] = getTokenBalance(tokenIds[i]);
        }
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

    /**
     * @dev floor 3 digits of $GOD amount
     * @param amount $GOD amount
     * @return floorAmount - the floor amount of $GOD
     */
    function _floorGodAmount(uint256 amount)
        internal
        pure
        returns (uint256 floorAmount)
    {
        floorAmount = (amount / 1e12) * 1e12;
    }
    
    /** STAKING */

    /**
     * @dev adds Merchant and Mobsters to the Clan and Pack
     * @param tokenIds the IDs of the Merchant and Mobsters to add to the clan
     */
    function addManyToClan(
        uint256[] calldata tokenIds,
        ITraits.DwarfTrait[] calldata traits
    ) external {
        require(_msgSender() == address(dwarfs_nft), "CALLER_NOT_DWARF");
        uint256 _totalGod;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (traits[i].level >= 5) {
                mapCityMobsters[traits[i].cityId].push(uint32(tokenIds[i]));
                contractInfo.lastCityID = traits[i].cityId;
            }

            TokenInfo memory _tokenInfo;
            _tokenInfo.tokenId = uint32(tokenIds[i]);
            _tokenInfo.cityId = traits[i].cityId;
            _tokenInfo.level = traits[i].level;
            _tokenInfo.availableBalance = (
                traits[i].level < 5
                    ? INITIAL_GOD_AMOUNT[traits[i].generation]
                    : 0
            );
            _tokenInfo.currentInvestedAmount = _tokenInfo.availableBalance;
            _tokenInfo.lastInvestedTime = uint128(block.timestamp);
            mapTokenInfo[tokenIds[i]] = _tokenInfo;

            _totalGod += _tokenInfo.currentInvestedAmount;
        }
        contractInfo.totalNumberOfTokens += uint32(tokenIds.length);
        remainingGodAmount += _totalGod;
    }

    /**
     * @dev add the single merchant to the city
     * @param tokenIds the IDs of the merchants token to add to the city
     * @param cityId the city id
     */
    function addManyMerchantsToCity(uint256[] calldata tokenIds, uint256 cityId)
        external
        whenNotPaused
    {
        require(
            mapCityMerchantCount[cityId] + tokenIds.length <=
                contractInfo.MAX_MERCHANT_COUNT,
            "CHOOSE_ANOTHER"
        );
        require(
            cityId > 0 && cityId <= contractInfo.lastCityID,
            "INVALID_CITY"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                dwarfs_nft.ownerOf(tokenIds[i]) == _msgSender(),
                "AINT YO TOKEN"
            );
            require(mapTokenInfo[tokenIds[i]].level < 5, "NOT_MERCHANT");
            require(mapTokenInfo[tokenIds[i]].cityId == 0, "ALREADY_IN_CITY");

            mapTokenInfo[tokenIds[i]].cityId = uint32(cityId);
            mapTokenInfo[tokenIds[i]].lastInvestedTime = uint128(
                block.timestamp
            );
        }
        mapCityMerchantCount[cityId] += tokenIds.length;
    }

    /**
     * @dev Calcualte the current available balance of a merchant to claim
     * @param tokenId the token id to calculate the available balance
     */
    function calcMerchantBalance(uint256 tokenId)
        internal
        view
        returns (uint256 availableBalance)
    {
        TokenInfo memory _tokenInfo = mapTokenInfo[tokenId];
        availableBalance = _tokenInfo.availableBalance;
        uint256 playingGame = (_tokenInfo.cityId > 0 &&
            contractInfo.bMerchantGamePlaying > 0)
            ? 1
            : 0;
        uint256 addedBalance = (_tokenInfo.currentInvestedAmount *
            playingGame *
            (block.timestamp - uint256(_tokenInfo.lastInvestedTime)) *
            contractInfo.DAILY_GOD_RATE) /
            100 /
            1 days;
        availableBalance += _floorGodAmount(addedBalance);
    }

    /**
     * @dev Calcualte the current available balance of a mobster to claim
     * @param tokenId the token id to calculate the available balance
     */
    function calcMobsterBalance(uint256 tokenId)
        internal
        view
        returns (uint256 availableBalance)
    {
        availableBalance = _floorGodAmount(
            ((mapCityTax[mapTokenInfo[tokenId].cityId] *
                mobsterProfitPercent[mapTokenInfo[tokenId].level - 5]) / 1000) -
                mapTokenInfo[tokenId].currentInvestedAmount
        );
    }

    /**
     * @dev Invest GODs
     * @param tokenId the token id to invest god
     * @param godAmount the invest amount
     */
    function investGods(uint256 tokenId, uint256 godAmount)
        external
        whenNotPaused
    {
        require(dwarfs_nft.ownerOf(tokenId) == _msgSender(), "AINT YO TOKEN");
        require(mapTokenInfo[tokenId].level < 5, "NOT_MERCHANT");
        require(godAmount >= MIN_INVESTED_AMOUNT, "GOD_INSUFFICIENT");
        require(mapTokenInfo[tokenId].cityId > 0, "OUT_OF_CITY");

        god.burn(_msgSender(), godAmount);
        mapTokenInfo[tokenId].availableBalance =
            calcMerchantBalance(tokenId) +
            godAmount;
        mapTokenInfo[tokenId].currentInvestedAmount += godAmount;
        mapTokenInfo[tokenId].lastInvestedTime = uint128(block.timestamp);

        remainingGodAmount += godAmount;
        emit TokenInvested(
            uint32(tokenId),
            mapTokenInfo[tokenId].lastInvestedTime,
            godAmount
        );
    }

    /** CLAIMING / RISKY */
    /**
     * @dev realize $GOD earnings and optionally unstake tokens from the Clan (Cities)
     * to unstake a Merchant it will require it has 2 days worth of $GOD unclaimed
     * @param tokenIds the IDs of the tokens to claim earnings from
     * @param bRisk the risky game flag (enable/disable)
     */
    function claimManyFromClan(uint256[] calldata tokenIds, bool bRisk)
        external
        whenNotPaused
    {
        uint256 owed;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(
                tokenIds[i] <= contractInfo.totalNumberOfTokens,
                "NOT_IN_CLAN"
            );

            if (mapTokenInfo[tokenIds[i]].level < 5) {
                owed += _claimMerchantFromCity(tokenIds[i], bRisk);
            } else owed += _claimMobsterFromCity(tokenIds[i]);
        }

        require(owed > 0, "NO_BALANCE");

        if (remainingGodAmount < owed) {
            contractInfo.bMerchantGamePlaying = 0;
            remainingGodAmount = 0;
        } else {
            remainingGodAmount -= owed;
        }

        god.mint(_msgSender(), owed);

        emit ClaimManyFromClan(tokenIds, owed, block.timestamp);
    }

    /**
     * @dev realize $GOD earnings for a single Merchant and optionally unstake it
     * if not unstaking, pay a 20% tax to the staked Mobsters
     * if unstaking, there is a 50% chance all $GOD is stolen
     * @param tokenId the ID of the Merchant to claim earnings from
     * @param bRisk the risky game flag
     * @return owed - the amount of $GOD earned
     */
    function _claimMerchantFromCity(uint256 tokenId, bool bRisk)
        internal
        returns (uint256 owed)
    {
        require(dwarfs_nft.ownerOf(tokenId) == _msgSender(), "AINT YO TOKEN");

        owed = calcMerchantBalance(tokenId);

        if (mapTokenInfo[tokenId].cityId > 0) {
            uint256 tax;
            if (bRisk == true) {
                // risky game
                if (random(block.timestamp) & 1 == 1) {
                    tax = owed;
                    owed = 0;
                }
            } else {
                tax = (owed * contractInfo.TAX_PERCENT) / 100;
                owed -= tax;
            }
            mapCityMerchantCount[mapTokenInfo[tokenId].cityId]--;
            mapCityTax[mapTokenInfo[tokenId].cityId] += tax;
            mapTokenInfo[tokenId].cityId = 0;
        }

        mapTokenInfo[tokenId].availableBalance = 0;
        mapTokenInfo[tokenId].currentInvestedAmount = 0;
    }

    /**
     * @dev realize $GOD earnings for a single Mobster
     * Mobsters earn $GOD proportional to their Level
     * @param tokenId the ID of the Mobster to claim earnings from
     * @return owed - the amount of $GOD earned
     */
    function _claimMobsterFromCity(uint256 tokenId)
        internal
        returns (uint256 owed)
    {
        require(dwarfs_nft.ownerOf(tokenId) == _msgSender(), "AINT YO TOKEN");

        owed = calcMobsterBalance(tokenId);
        mapTokenInfo[tokenId].currentInvestedAmount += owed;
        mapTokenInfo[tokenId].lastInvestedTime = uint128(block.timestamp);
    }

    /** ADMIN */

    /**
     * @dev enables owner to pause / unpause minting
     * @param _bPaused the flag to pause or unpause
     */
    function setPaused(bool _bPaused) external onlyOwner {
        if (_bPaused) _pause();
        else _unpause();
    }

    /**
     * @dev set the daily god earning rate
     * @param _dailyGodRate the daily god earning rate
     */
    function setDailyGodRate(uint32 _dailyGodRate) public onlyOwner {
        contractInfo.DAILY_GOD_RATE = _dailyGodRate;
    }

    /**
     * @dev set the tax percent of a merchant
     * @param _taxPercent the tax percent
     */
    function setTaxPercent(uint32 _taxPercent) public onlyOwner {
        contractInfo.TAX_PERCENT = _taxPercent;
    }

    /**
     * @dev set the max global god amount
     * @param _maxGlobalGod the god amount
     */
    function setMaxGlobalGodAmount(uint256 _maxGlobalGod) public onlyOwner {
        MAXIMUM_GLOBAL_GOD = _maxGlobalGod;
    }

    /**
     * @dev set the initial god amount of a merchant
     * @param _initialGodAmount the god amount
     */
    function setInitialGodAmount(uint256[] calldata _initialGodAmount)
        public
        onlyOwner
    {
        INITIAL_GOD_AMOUNT = _initialGodAmount;
    }

    /**
     * @dev set the min god amount for investing
     * @param _minInvestedAmount the god amount
     */
    function setMinInvestedAmount(uint256 _minInvestedAmount) public onlyOwner {
        MIN_INVESTED_AMOUNT = _minInvestedAmount;
    }

    /**
     * @dev set the mobster profit percent (dwarfsoldier, dwarfcapos, boss and dwarfather)
     * @param _mobsterProfits the percent array
     */
    function setMobsterProfitPercent(uint32[] memory _mobsterProfits)
        public
        onlyOwner
    {
        mobsterProfitPercent = _mobsterProfits;
    }

    /**
     * @dev set the Dwarf NFT address
     * @param _dwarfNFT the Dwarf NFT address
     */
    function setDwarfNFT(address _dwarfNFT) external onlyOwner {
        dwarfs_nft = IDwarfs_NFT(_dwarfNFT);
    }

    /**
     * @dev set the GOD address
     * @param _god the GOD address
     */
    function setGod(address _god) external onlyOwner {
        god = IGOD(_god);
    }

    /**
     * @dev set the max merchant count for a city
     * @param _maxMerchantCount the MAX_MERCHANT_COUNT value
     */
    function setMaxMerchantCount(uint32 _maxMerchantCount) external onlyOwner {
        contractInfo.MAX_MERCHANT_COUNT = _maxMerchantCount;
    }
}
