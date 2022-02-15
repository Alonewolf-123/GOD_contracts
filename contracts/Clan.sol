// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./Pausable.sol";
import "./Dwarfs_NFT.sol";
import "./GOD.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

contract Clan is Initializable, Ownable, IERC721ReceiverUpgradeable, Pausable {

    // number of cities in each generation status
    uint8[] private MAX_NUM_CITY = [6, 9, 12, 15];

    // struct to store a token information
    struct TokenInfo {
        uint16 tokenId;
        uint256 availableBalance;
        uint256 currentInvestedAmount;
        uint80 lastInvestedTime;
    }

    event TokenInvested(uint256 tokenId, uint256 lastInvestedTime);
    event MerchantClaimed(uint256 tokenId, uint256 earned);
    event MobsterClaimed(uint256 tokenId, uint256 earned);

    // reference to the Dwarfs_NFT NFT contract
    Dwarfs_NFT dwarfs_nft;

    // reference to the $GOD contract for minting $GOD earnings
    GOD god;

    mapping(uint32 => TokenInfo) private mapTokenInfo;
    mapping(uint32 => bool) private mapTokenExisted;

    // merchant earn 1% of investment of $GOD per day
    uint256 private constant DAILY_GOD_RATE = 1;

    // riskygame merchant must have 2 days worth of $GOD to unstake or else it's too cold
    uint256 private constant MIN_TO_EXIT_RISKY = 2 days;

    // mobsters take 15% on all $GOD claimed
    uint256 private constant GOD_CLAIM_TAX_PERCENTAGE = 15;

    // casino vault take 5% on all $GOD claimed
    uint256 private constant CASINO_VAULT_PERCENTAGE = 5;

    // there will only ever be (roughly) 2.4 billion $GOD earned through staking
    uint256 private constant MAXIMUM_GLOBAL_GOD = 2400000000 ether;

    // initial Balance of a new Merchant
    uint256 private constant INITIAL_GOD_AMOUNT = 100000 ether;

    // requested god amount for casino play
    uint256 private constant REQUESTED_GOD_CASINO = 1000 ether;

    // amount of $GOD earned so far
    uint256 private totalGodEarned = 0;

    // amount of casino vault $GOD
    uint256 private casinoVault = 0;

    // profit percent of each mobster; x 0.1 %
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
    function addManyToClan(
        uint16[] calldata tokenIds
    ) external {
        require(
            _msgSender() == address(dwarfs_nft),
            "Caller Must Be Dwarfs NFT Contract"
        );
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _addToCity(tokenIds[i]);
        }
    }

    /**
     * adds a single token to the city
     * @param account the address of the staker
     * @param tokenId the ID of the Merchant to add to the Clan
     */
    function _addToCity(
        uint16 tokenId
    ) internal whenNotPaused {
        IDwarfs_NFT.DwarfTrait memory t = dwarfs_nft.getTokenTraits(tokenId);
        if (mapTokenExisted[tokenId] == false) {
            mapTokenInfo[tokenId].push(
                TokenInfo({
                    tokenId: tokenId,
                    availableBalance: 
                    timestamp: uint80(block.timestamp)
                })
            );
            mapTokenExisted[tokenId] = true;
        }
        
        

        emit TokenInvested(tokenId, block.timestamp);
    }

    function getStackIndexByTokenId(uint16 tokenId, uint8 cityId)
        internal
        view
        returns (uint256 index)
    {
        require(mapTokenExisted[tokenId] == true, "No existed token");
        for (uint256 i = 0; i < mapTokenInfo[cityId].length; i++) {
            if (mapTokenInfo[cityId][i].tokenId == tokenId) {
                return index;
            }
        }
    }

    /**
     * Invest GODs
     */
    function investGods(uint16 tokenId, uint256 godAmount) external {
        require(dwarfs_nft.ownerOf(tokenId) == _msgSender(), "AINT YO TOKEN");

        god.burn(_msgSender(), godAmount);
        uint8 cityId = dwarfs_nft.getTokenTraits(tokenId).cityId;
        Stake memory stake = mapTokenInfo[cityId][
            getStackIndexByTokenId(tokenId, cityId)
        ];
        dwarfsRewards[tokenId] +=
            ((
                (uint80(block.timestamp) - stake.timestamp) * gods[tokenId] == 0
                    ? INITIAL_GOD_AMOUNT
                    : gods[tokenId] * DAILY_GOD_RATE
            ) / 100) /
            1 days;

        stake.timestamp = uint80(block.timestamp);
        gods[tokenId] == 0
            ? gods[tokenId] = INITIAL_GOD_AMOUNT + godAmount
            : gods[tokenId] += godAmount;
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
                mapTokenExisted[tokenIds[i]] == true,
                "No existed token"
            );

            if (dwarfs_nft.getTokenTraits(tokenIds[i]).isMerchant)
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
        uint8 cityId = dwarfs_nft.getTokenTraits(tokenId).cityId;
        uint256 index = getStackIndexByTokenId(tokenId, cityId);
        Stake memory stake = mapTokenInfo[cityId][index];
        require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");
        require(totalGodEarned < MAXIMUM_GLOBAL_GOD, "LIMIT GOD ERROR");
        if (isRisky == true) {
            require(
                block.timestamp - stake.timestamp < MIN_TO_EXIT_RISKY,
                "LIMIT EXIT TIME 2DAYS"
            );
        }

        owed +=
            ((
                (uint80(block.timestamp) - stake.timestamp) * gods[tokenId] == 0
                    ? INITIAL_GOD_AMOUNT
                    : gods[tokenId] * DAILY_GOD_RATE
            ) / 100) /
            1 days +
            dwarfsRewards[tokenId];
        dwarfsRewards[tokenId] = 0;

        uint256 m_dwarfsRewards = 0;
        if (isRisky == true) {
            // risky game
            if (random(tokenId) & 1 == 1) {
                // 50%
                m_dwarfsRewards += owed;
                owed = 0;
            }
        } else {
            m_dwarfsRewards += (owed * GOD_CLAIM_TAX_PERCENTAGE) / 100;
            casinoVault += (owed * CASINO_VAULT_PERCENTAGE) / 100;
            owed =
                (owed *
                    (100 -
                        GOD_CLAIM_TAX_PERCENTAGE -
                        CASINO_VAULT_PERCENTAGE)) /
                100;
            distributeToMobsters(cityId, m_dwarfsRewards);
        }

        delete mapTokenInfo[cityId][index];
        
        emit MerchantClaimed(tokenId, owed);
    }

    function distributeToMobsters(uint8 cityId, uint256 amount) internal {
        uint16[] memory mobsters = getMobstersByCityId(cityId);
        for (uint16 i = 0; i < mobsters.length; i++) {
            dwarfsRewards[mobsters[i]] =
                (amount *
                    mobsterProfits[
                        dwarfs_nft.getTokenTraits(mobsters[i]).alphaIndex - 5
                    ]) /
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

        owed = dwarfsRewards[tokenId];
        dwarfsRewards[tokenId] = 0;

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
        god.burn(_msgSender(), REQUESTED_GOD_CASINO);

        casinoVault += REQUESTED_GOD_CASINO;
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

    function getMaxNumCityOfGen() external view returns (uint8) {
        return MAX_NUM_CITY;
    }

    function setMaxNumCityOfGen(uint8[] maxCity) external onlyOwner {
        require(maxCity.length == MAX_NUM_CITY.length, "Invalid parameters");
        for (uint8 i = 0; i < maxCity.length; i++) {
             MAX_NUM_CITY[i] = maxCity[i];
        }
    }

    /* Get the available city id */
    function getAvailableCity() internal view returns (uint8) {
        for (uint8 i = 0; i < MAX_NUM_CITY; i++) {
            if (mapTokenInfo[i].length < 200) {
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
        for (uint256 i = 0; i < mapTokenInfo[cityId].length; i++) {
            if (
                dwarfs_nft
                    .getTokenTraits(mapTokenInfo[cityId][i].tokenId)
                    .isMerchant == false
            ) {
                tokenIds[index] = mapTokenInfo[cityId][i].tokenId;
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
        for (uint16 i = 0; i < mapTokenInfo[cityId].length; i++) {
            alpha = dwarfs_nft
                .getTokenTraits(mapTokenInfo[cityId][i].tokenId)
                .alphaIndex;
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
