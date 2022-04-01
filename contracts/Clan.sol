// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./Dwarfs_NFT.sol";
import "./GOD.sol";

/// @title Clan
/// @author Bounyavong
/// @dev Clan logic is implemented and this is the upgradeable
contract Clan is
    OwnableUpgradeable,
    PausableUpgradeable
{
    // struct to store a token information
    struct TokenInfo {
        uint32 tokenId;
        uint8 cityId;
        uint256 availableBalance;
        uint256 currentInvestedAmount;
        uint80 lastInvestedTime;
    }

    // event when token invested
    event TokenInvested(
        uint32 tokenId,
        uint256 investedAmount,
        uint80 lastInvestedTime
    );
    // event when merchant claimed
    event MerchantClaimed(uint32 tokenId, uint256 earned);
    // event when mobster claimed
    event MobsterClaimed(uint32 tokenId, uint256 earned);

    // reference to the Dwarfs_NFT NFT contract
    Dwarfs_NFT public dwarfs_nft;

    // reference to the $GOD contract for minting $GOD earnings
    GOD public god;

    // token information map
    mapping(uint32 => TokenInfo) private mapTokenInfo;
    // map to check the existed token
    mapping(uint32 => bool) private mapTokenExisted;

    // total number of tokens in the clan
    uint32 public totalNumberOfTokens;

    // map of mobster IDs for cityId
    mapping(uint8 => uint32[]) private mapCityMobsters;

    // map of merchant count for cityId
    mapping(uint8 => uint32) private mapCityMerchantCount;

    // max merchant count for a city
    uint32 public MAX_MERCHANT_COUNT;

    // merchant earn 1% of investment of $GOD per day
    uint8 public DAILY_GOD_RATE;

    // mobsters take 15% on all $GOD claimed
    uint8 public TAX_PERCENT;

    // there will only ever be (roughly) 2.4 billion $GOD earned through staking
    uint256 public MAXIMUM_GLOBAL_GOD;

    // initial Balance of a new Merchant
    uint256 public INITIAL_GOD_AMOUNT;

    // minimum GOD invested amount
    uint256 public MIN_INVESTED_AMOUNT;

    // amount of $GOD earned so far
    uint256 public remainingGodAmount;

    // profit percent of each mobster; x 0.1 %
    uint8[] public mobsterProfitPercent;

    // playing merchant game enabled
    bool public bMerchantGamePlaying;

    // the last cityID in the clan
    uint8 public lastCityID;

    event AddManyToClan(uint32[] tokenIds, uint256 timestamp);
    event ClaimManyFromClan(uint32[] tokenIds, uint256 timestamp);

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
        dwarfs_nft = Dwarfs_NFT(_dwarfs_nft);
        god = GOD(_god);

        // total number of tokens in the clan
        totalNumberOfTokens = 0;

        // merchant earn 1% of investment of $GOD per day
        DAILY_GOD_RATE = 1;

        // mobsters take 20% on all $GOD claimed
        TAX_PERCENT = 20;

        // there will only ever be (roughly) 2.4 billion $GOD earned through staking
        MAXIMUM_GLOBAL_GOD = 3000000000 ether;

        // initial Balance of a new Merchant
        INITIAL_GOD_AMOUNT = 100000 ether;

        // minimum GOD invested amount
        MIN_INVESTED_AMOUNT = 1000 ether;

        // amount of $GOD earned so far
        remainingGodAmount = MAXIMUM_GLOBAL_GOD;

        // profit percent of each mobster; x 0.1 %
        mobsterProfitPercent = [4, 7, 14, 29];

        // playing merchant game enabled
        bMerchantGamePlaying = true;

        MAX_MERCHANT_COUNT = 1200;

        lastCityID = 1;

        _pause();
    }

    /** STAKING */
    /**
     * @dev adds Merchant and Mobsters to the Clan and Pack
     * @param tokenIds the IDs of the Merchant and Mobsters to add to the clan
     */
    function addManyToClan(uint32[] calldata tokenIds) external {
        require(
            _msgSender() == address(dwarfs_nft),
            "Caller Must Be Dwarfs NFT Contract"
        );
        for (uint16 i = 0; i < tokenIds.length; i++) {
            _addToCity(tokenIds[i]);
        }

        emit AddManyToClan(tokenIds, block.timestamp);
    }

    /**
     * @dev adds a single token to the city
     * @param tokenId the ID of the Merchant to add to the city
     */
    function _addToCity(uint32 tokenId) internal {
        require(
            mapTokenExisted[tokenId] == false,
            "The token has been added to the clan already"
        );

        ITraits.DwarfTrait memory t = dwarfs_nft.getTokenTraits(tokenId);

        // Add a mobster to a city
        if (t.isMerchant == false) {
            mapCityMobsters[t.cityId].push(tokenId);
            lastCityID = t.cityId;
        }

        TokenInfo memory _tokenInfo;
        _tokenInfo.tokenId = tokenId;
        _tokenInfo.cityId = t.cityId;
        _tokenInfo.availableBalance = (t.isMerchant ? INITIAL_GOD_AMOUNT : 0);
        _tokenInfo.currentInvestedAmount = _tokenInfo.availableBalance;
        _tokenInfo.lastInvestedTime = uint80(block.timestamp);
        mapTokenInfo[tokenId] = _tokenInfo;
        mapTokenExisted[tokenId] = true;
        totalNumberOfTokens++;

        remainingGodAmount += _tokenInfo.currentInvestedAmount;
        emit TokenInvested(
            tokenId,
            _tokenInfo.currentInvestedAmount,
            _tokenInfo.lastInvestedTime
        );
    }

    /**
     * @dev add the single merchant to the city
     * @param tokenIds the IDs of the merchants token to add to the city
     * @param cityId the city id
     */
    function addManyMerchantsToCity(uint32[] calldata tokenIds, uint8 cityId) external whenNotPaused {
        require(mapCityMerchantCount[cityId] + tokenIds.length <= MAX_MERCHANT_COUNT, "Please select another city or reduce the count of the merchants");
        require(cityId > 0 && cityId <= lastCityID, "Invalid cityId");
        for (uint16 i = 0; i < tokenIds.length; i++) {
            _addMerchantToCity(tokenIds[i], cityId);
        }
        mapCityMerchantCount[cityId] += uint32(tokenIds.length);
    }

    /**
     * @dev add the single merchant to the city
     * @param tokenId the ID of the merchant token to add to the city
     * @param cityId the city id
     */
    function _addMerchantToCity(uint32 tokenId, uint8 cityId) internal {
        require(dwarfs_nft.ownerOf(tokenId) == _msgSender(), "AINT YO TOKEN");
        require(
            dwarfs_nft.getTokenTraits(tokenId).isMerchant == true,
            "The token must be a Merchant"
        );
        require(
            mapTokenInfo[tokenId].cityId == 0,
            "The Merchant must be out of a city"
        );

        mapTokenInfo[tokenId].cityId = cityId;
        mapTokenInfo[tokenId].lastInvestedTime = uint80(block.timestamp);
    }

    /**
     * @dev Calcualte the current available balance to claim
     * @param tokenId the token id to calculate the available balance
     */
    function calcAvailableBalance(uint32 tokenId)
        internal
        view
        returns (uint256 availableBalance)
    {
        TokenInfo memory _tokenInfo = mapTokenInfo[tokenId];
        availableBalance = _tokenInfo.availableBalance;
        uint8 playingGame = (_tokenInfo.cityId > 0 &&
            bMerchantGamePlaying == true)
            ? 1
            : 0;
        uint256 addedBalance = (_tokenInfo.currentInvestedAmount *
            playingGame *
            (uint80(block.timestamp) - _tokenInfo.lastInvestedTime) *
            DAILY_GOD_RATE) /
            100 /
            1 days;
        availableBalance += addedBalance;

        return availableBalance;
    }

    /**
     * @dev Invest GODs
     * @param tokenId the token id to invest god
     * @param godAmount the invest amount
     */
    function investGods(uint32 tokenId, uint256 godAmount) external whenNotPaused {
        require(dwarfs_nft.ownerOf(tokenId) == _msgSender(), "AINT YO TOKEN");
        require(
            dwarfs_nft.getTokenTraits(tokenId).isMerchant == true,
            "The token must be a Merchant"
        );
        require(
            godAmount >= MIN_INVESTED_AMOUNT,
            "The GOD investing amount is too small."
        );
        require(mapTokenInfo[tokenId].cityId > 0, "The merchant must be in a city.");

        god.burn(_msgSender(), godAmount);
        mapTokenInfo[tokenId].availableBalance = calcAvailableBalance(tokenId) + godAmount;
        mapTokenInfo[tokenId].currentInvestedAmount += godAmount;
        mapTokenInfo[tokenId].lastInvestedTime = uint80(block.timestamp);

        remainingGodAmount += godAmount;
        emit TokenInvested(
            tokenId,
            godAmount,
            mapTokenInfo[tokenId].lastInvestedTime
        );
    }

    /** CLAIMING / RISKY */
    /**
     * @dev realize $GOD earnings and optionally unstake tokens from the Clan (Cities)
     * to unstake a Merchant it will require it has 2 days worth of $GOD unclaimed
     * @param tokenIds the IDs of the tokens to claim earnings from
     * @param bRisk the risky game flag (enable/disable)
     */
    function claimManyFromClan(uint32[] calldata tokenIds, bool bRisk)
        external
        whenNotPaused
    {
        uint256 owed = 0;
        for (uint16 i = 0; i < tokenIds.length; i++) {
            require(
                mapTokenExisted[tokenIds[i]] == true,
                "The token isn't existed in the clan"
            );

            if (dwarfs_nft.getTokenTraits(tokenIds[i]).isMerchant)
                owed += _claimMerchantFromCity(tokenIds[i], bRisk);
            else owed += _claimMobsterFromCity(tokenIds[i]);
        }

        require(owed > 0, "There is no balance to claim");

        if (remainingGodAmount < owed) {
            bMerchantGamePlaying = false;
            remainingGodAmount = 0;
        } else {
            remainingGodAmount -= owed;
        }

        for (uint16 i = 0; i < tokenIds.length; i++) {
            mapTokenInfo[tokenIds[i]].availableBalance = 0;
            mapTokenInfo[tokenIds[i]].currentInvestedAmount = 0;
        }
        god.mint(_msgSender(), owed);

        emit ClaimManyFromClan(tokenIds, block.timestamp);
    }

    /**
     * @dev realize $GOD earnings for a single Merchant and optionally unstake it
     * if not unstaking, pay a 20% tax to the staked Mobsters
     * if unstaking, there is a 50% chance all $GOD is stolen
     * @param tokenId the ID of the Merchant to claim earnings from
     * @param bRisk the risky game flag
     * @return owed - the amount of $GOD earned
     */
    function _claimMerchantFromCity(uint32 tokenId, bool bRisk)
        internal
        returns (uint256 owed)
    {
        require(dwarfs_nft.ownerOf(tokenId) == _msgSender(), "AINT YO TOKEN");

        owed = calcAvailableBalance(tokenId);

        if (mapTokenInfo[tokenId].cityId == 0) {
            // This token is out of city.
            return owed;
        }

        if (bRisk == true) {
            // risky game
            if (random(random(block.timestamp)) & 1 == 1) {
                // 50%
                _distributeTaxes(mapTokenInfo[tokenId].cityId, owed);
                owed = 0;
            }
        } else {
            _distributeTaxes(
                mapTokenInfo[tokenId].cityId,
                (owed * TAX_PERCENT) / 100
            );
        }

        mapCityMerchantCount[mapTokenInfo[tokenId].cityId]--;
        mapTokenInfo[tokenId].cityId = 0;

        emit MerchantClaimed(tokenId, owed);
    }

    /**
     * @dev distribute the taxes to mobsters in city
     * @param cityId the city id
     * @param amount the tax amount to distribute
     */
    function _distributeTaxes(uint8 cityId, uint256 amount) internal {
        for (uint16 i = 0; i < mapCityMobsters[cityId].length; i++) {
            uint32 mobsterId = mapCityMobsters[cityId][i];

            mapTokenInfo[mobsterId].availableBalance +=
                (amount *
                    mobsterProfitPercent[
                        dwarfs_nft.getTokenTraits(mobsterId).level - 5
                    ]) /
                1000;
        }
    }

    /**
     * @dev realize $GOD earnings for a single Mobster
     * Mobsters earn $GOD proportional to their Level
     * @param tokenId the ID of the Mobster to claim earnings from
     * @return owed - the amount of $GOD earned
     */
    function _claimMobsterFromCity(uint32 tokenId)
        internal
        returns (uint256 owed)
    {
        require(dwarfs_nft.ownerOf(tokenId) == _msgSender(), "Invalid Owner");

        owed = mapTokenInfo[tokenId].availableBalance;

        // Not implemented yet
        emit MobsterClaimed(tokenId, owed);
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
    function setDailyGodRate(uint8 _dailyGodRate) public onlyOwner{
        DAILY_GOD_RATE = _dailyGodRate;
    }

    /**
     * @dev set the tax percent of a merchant
     * @param _taxPercent the tax percent
     */
    function setTaxPercent(uint8 _taxPercent) public onlyOwner{
        TAX_PERCENT = _taxPercent;
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
    function setInitialGodAmount(uint256 _initialGodAmount) public onlyOwner{
        INITIAL_GOD_AMOUNT = _initialGodAmount;
    }

    /**
     * @dev set the min god amount for investing
     * @param _minInvestedAmount the god amount
     */
    function setMinInvestedAmount(uint256 _minInvestedAmount) public onlyOwner{
        MIN_INVESTED_AMOUNT = _minInvestedAmount;
    }

    /**
     * @dev set the mobster profit percent (dwarfsoldier, dwarfcapos, boss and dwarfather)
     * @param _mobsterProfits the percent array
     */
    function setMobsterProfitPercent(uint8[] memory _mobsterProfits) public onlyOwner{
        mobsterProfitPercent = _mobsterProfits;
    }

    /**
     * @dev set the Dwarf NFT address
     * @param _dwarfNFT the Dwarf NFT address
     */
    function setDwarfNFT(address _dwarfNFT) external onlyOwner {
        dwarfs_nft = Dwarfs_NFT(_dwarfNFT);
    }

    /**
     * @dev set the GOD address
     * @param _god the GOD address
     */
    function setGod(address _god) external onlyOwner {
        god = GOD(_god);
    }

    /**
     * @dev set the max merchant count for a city
     * @param _maxMerchantCount the MAX_MERCHANT_COUNT value
     */
    function setMaxMerchantCount(uint32 _maxMerchantCount) external onlyOwner {
        MAX_MERCHANT_COUNT = _maxMerchantCount;
    }

    /**
     * @dev get the current information of the selected tokens
     * @param tokenIds the IDs of the tokens
     */
    function getDwarfsTokenInfo(uint32[] calldata tokenIds) external view returns (TokenInfo[] memory){
        TokenInfo[] memory tokenInfos = new TokenInfo[](tokenIds.length);
        for (uint16 i = 0; i < tokenIds.length; i++) {
            tokenInfos[i] = mapTokenInfo[tokenIds[i]];
        }

        return tokenInfos;
    }

    /**
     * @dev get the Merchant count of the selected city
     * @param _cityId the Id of the city
     */
    function getMerchantCountOfCity(uint8 _cityId) external view returns (uint32){
        return mapCityMerchantCount[_cityId];
    }

    /**
     * @dev get the Merchant Ids of the selected city
     * @param _cityId the Id of the city
     */
    function getMerchantIdsOfCity(uint8 _cityId) external view returns (uint32[] memory){
        require(mapCityMerchantCount[_cityId] > 0, "There is no merchant in the city");

        uint32[] memory tokenIds = new uint32[](mapCityMerchantCount[_cityId]);
        uint32 count = 0;
        for (uint32 i = 1; i <= totalNumberOfTokens; i++) {
            if (dwarfs_nft.getTokenTraits(i).isMerchant == true) {
                if (mapTokenInfo[i].cityId == _cityId) {
                    tokenIds[count] = i;
                    count++;
                }
            }
        }

        return tokenIds;
    }

    /**
     * @dev get the Mobster Ids of the selected city
     * @param _cityId the Id of the city
     */
    function getMobsterIdsOfCity(uint8 _cityId) external view returns (uint32[] memory){
        return mapCityMobsters[_cityId];
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
}
