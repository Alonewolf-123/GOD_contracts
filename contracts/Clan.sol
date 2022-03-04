// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./Dwarfs_NFT.sol";
import "./GOD.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

/// @title Clan
/// @author Bounyavong
/// @dev Clan logic is implemented and this is the upgradeable
contract Clan is IERC721ReceiverUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    // number of cities in each generation status
    uint8[] private MAX_NUM_CITY;

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
    Dwarfs_NFT dwarfs_nft;

    // reference to the $GOD contract for minting $GOD earnings
    GOD god;

    // token information map
    mapping(uint32 => TokenInfo) private mapTokenInfo;
    // map to check the existed token
    mapping(uint32 => bool) private mapTokenExisted;

    // total number of tokens in the clan
    uint32 private totalNumberOfTokens;

    // map of mobster IDs for cityId
    mapping(uint8 => uint32[]) private mapCityMobsters;

    // merchant earn 1% of investment of $GOD per day
    uint8 private DAILY_GOD_RATE;

    // mobsters take 15% on all $GOD claimed
    uint8 private TAX_PERCENT;

    // there will only ever be (roughly) 2.4 billion $GOD earned through staking
    uint256 private MAXIMUM_GLOBAL_GOD;

    // initial Balance of a new Merchant
    uint256 private INITIAL_GOD_AMOUNT;

    // minimum GOD invested amount
    uint256 private MIN_INVESTED_AMOUNT;

    // amount of $GOD earned so far
    uint256 private remainingGodAmount;

    // profit percent of each mobster; x 0.1 %
    uint8[] private mobsterProfitPercent;

    // playing merchant game enabled
    bool private bMerchantGamePlaying;

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

        // number of cities in each generation status
        MAX_NUM_CITY = [6, 9, 12, 15];

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
    }

    /**
     * @dev adds a single token to the city
     * @param tokenId the ID of the Merchant to add to the city
     */
    function _addToCity(uint32 tokenId) internal whenNotPaused {
        require(
            mapTokenExisted[tokenId] == false,
            "The token has been added to the clan already"
        );

        IDwarfs_NFT.DwarfTrait memory t = dwarfs_nft.getTokenTraits(tokenId);

        // Add a mobster to a city
        if (t.isMerchant == false) {
            mapCityMobsters[t.cityId].push(tokenId);
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
     * @param tokenId the ID of the merchant token to add to the city
     * @param cityId the city id
     */
    function addMerchantToCity(uint32 tokenId, uint8 cityId) external {
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
    function investGods(uint32 tokenId, uint256 godAmount) external {
        require(dwarfs_nft.ownerOf(tokenId) == _msgSender(), "AINT YO TOKEN");
        require(
            dwarfs_nft.getTokenTraits(tokenId).isMerchant == true,
            "The token must be a Merchant"
        );
        require(
            godAmount >= MIN_INVESTED_AMOUNT,
            "The GOD investing amount is too small."
        );

        god.burn(_msgSender(), godAmount);
        mapTokenInfo[tokenId].availableBalance = calcAvailableBalance(tokenId);
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
            mapTokenInfo[tokenIds[i]].lastInvestedTime = uint80(
                block.timestamp
            );
        }
        god.mint(_msgSender(), owed);
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
     * @dev get max number of cities of each generation
     * @return number of city array
     */
    function getMaxNumCityOfGen() external view returns (uint8[] memory) {
        return MAX_NUM_CITY;
    }

    /**
     * @dev set max number of cities of each generation
     * @param maxCity the number of city array
     */
    function setMaxNumCityOfGen(uint8[] memory maxCity) external onlyOwner {
        require(maxCity.length == MAX_NUM_CITY.length, "Invalid parameters");
        for (uint8 i = 0; i < maxCity.length; i++) {
            MAX_NUM_CITY[i] = maxCity[i];
        }
    }

    /**
     * @dev Get the available city id
     * @return the available city id
     */
    function getAvailableCity() public view virtual returns (uint8) {
        uint8 cityId = 1;
        while (true) {
            uint16[] memory _maxMobstersPerCity = dwarfs_nft
                .getMaxMobstersPerCity();
            if (
                mapCityMobsters[cityId].length <
                (_maxMobstersPerCity[0] +
                    _maxMobstersPerCity[1] +
                    _maxMobstersPerCity[2] +
                    _maxMobstersPerCity[3])
            ) {
                return cityId;
            }
            cityId++;
        }

        return cityId;
    }

    /**
     * @dev Get the number of mobsters in city
     * @return the number of mobsters array
     */
    function getNumMobstersOfCity(uint8 cityId)
        public
        view
        returns (uint16[] memory)
    {
        uint16[] memory _numOfMobstersOfCity = new uint16[](4);
        uint8 level = 0;
        for (uint32 i = 0; i < mapCityMobsters[cityId].length; i++) {
            level = dwarfs_nft
                .getTokenTraits(mapCityMobsters[cityId][i])
                .level;
            _numOfMobstersOfCity[level - 5]++;
        }

        return _numOfMobstersOfCity;
    }

    /**
     * @dev Get the daily god earning rate
     * @return the daily god earning rate
     */
    function getDailyGodRate() public view returns (uint8) {
        return DAILY_GOD_RATE;
    }

    /**
     * @dev set the daily god earning rate
     * @param _dailyGodRate the daily god earning rate
     */
    function setDailyGodRate(uint8 _dailyGodRate) public {
        DAILY_GOD_RATE = _dailyGodRate;
    }

    /**
     * @dev Get the tax percent of a merchant
     * @return the tax percent
     */
    function getTaxPercent() public view returns (uint8) {
        return TAX_PERCENT;
    }

    /**
     * @dev set the tax percent of a merchant
     * @param _taxPercent the tax percent
     */
    function setTaxPercent(uint8 _taxPercent) public {
        TAX_PERCENT = _taxPercent;
    }

    /**
     * @dev Get the max global god amount
     * @return the god amount
     */
    function getMaxGlobalGodAmount() public view returns (uint256) {
        return MAXIMUM_GLOBAL_GOD;
    }

    /**
     * @dev set the max global god amount
     * @param _maxGlobalGod the god amount
     */
    function setMaxGlobalGodAmount(uint8 _maxGlobalGod) public {
        MAXIMUM_GLOBAL_GOD = _maxGlobalGod;
    }

    /**
     * @dev Get the initial god amount of a merchant
     * @return the god amount
     */
    function getInitialGodAmount() public view returns (uint256) {
        return INITIAL_GOD_AMOUNT;
    }

    /**
     * @dev set the initial god amount of a merchant
     * @param _initialGodAmount the god amount
     */
    function setInitialGodAmount(uint8 _initialGodAmount) public {
        INITIAL_GOD_AMOUNT = _initialGodAmount;
    }

    /**
     * @dev Get the min god amount for investing
     * @return the god amount
     */
    function getMinInvestedAmount() public view returns (uint256) {
        return MIN_INVESTED_AMOUNT;
    }

    /**
     * @dev set the min god amount for investing
     * @param _minInvestedAmount the god amount
     */
    function setMinInvestedAmount(uint256 _minInvestedAmount) public {
        MIN_INVESTED_AMOUNT = _minInvestedAmount;
    }

    /**
     * @dev Get the mobster profit percent (dwarfsoldier, dwarfcapos, boss and dwarfather)
     * @return the percent array
     */
    function getMobsterProfitPercent() public view returns (uint8[] memory) {
        return mobsterProfitPercent;
    }

    /**
     * @dev set the mobster profit percent (dwarfsoldier, dwarfcapos, boss and dwarfather)
     * @param _mobsterProfits the percent array
     */
    function setMobsterProfitPercent(uint8[] memory _mobsterProfits) public {
        mobsterProfitPercent = _mobsterProfits;
    }

    /**
     * @dev Get the total number of tokens
     * @return the number of tokens
     */
    function getTotalNumberOfTokens() public view returns (uint256) {
        return totalNumberOfTokens;
    }

    /**
     * @dev get the Dwarf NFT address
     * @return the Dwarf NFT address
     */
    function getDwarfNFT() public view returns (address) {
        return address(dwarfs_nft);
    }

    /**
     * @dev set the Dwarf NFT address
     * @param _dwarfNFT the Dwarf NFT address
     */
    function setDwarfNFT(address _dwarfNFT) external onlyOwner {
        dwarfs_nft = Dwarfs_NFT(_dwarfNFT);
    }

    /**
     * @dev get the GOD address
     * @return the GOD address
     */
    function getGod() public view returns (address) {
        return address(god);
    }

    /**
     * @dev set the GOD address
     * @param _god the GOD address
     */
    function setGod(address _god) external onlyOwner {
        god = GOD(_god);
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
