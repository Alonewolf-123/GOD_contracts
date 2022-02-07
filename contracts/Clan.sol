// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;

import "./IERC721Receiver.sol";
import "./Pausable.sol";
import "./Dwarfs_NFT.sol";
import "./GOD.sol";

contract Clan is Ownable, IERC721Receiver, Pausable {
    // maximum alpha score for a Mobster
    uint8 public constant MAX_ALPHA = 8;

    uint8 public MAX_NUM_CITY = 6;

    // struct to store a stake's token, owner, and earning values
    struct Stake {
        uint16 tokenId;
        uint80 value;
        address owner;
    }

    event TokenStaked(address owner, uint256 tokenId, uint256 value);
    event MerchantClaimed(uint256 tokenId, uint256 earned);
    event MobsterClaimed(uint256 tokenId, uint256 earned);

    // reference to the Dwarfs_NFT NFT contract
    Dwarfs_NFT dwarfs_nft;

    // reference to the $GOD contract for minting $GOD earnings
    GOD god;

    mapping(uint8 => Stake[]) public cities;
    mapping(uint8 => uint256) public cityPots;

    // merchant earn 10000 $GOD per day
    uint256 public constant DAILY_GOD_RATE = 1;

    // merchant must have 2 days worth of $GOD to unstake or else it's too cold
    uint256 public constant MINIMUM_TO_EXIT = 2 days;

    // mobsters take a 20% tax on all $GOD claimed
    uint256 public constant GOD_CLAIM_TAX_PERCENTAGE = 20;

    // there will only ever be (roughly) 2.4 billion $GOD earned through staking
    uint256 public constant MAXIMUM_GLOBAL_GOD = 2400000000 ether;

    // amount of $GOD earned so far
    uint256 public totalGodEarned;
    // number of Merchant staked in the Clan
    uint256 public totalMerchantStaked;
    // the last time $GOD was claimed
    uint256 public lastClaimTimestamp;

    // profit of dwarfather
    uint256 public profitOfDwarfather = 40;
    // profit of boss
    uint256 public profitOfBoss = 30;
    // profit of dwarfcapos
    uint256 public profitOfDwarfCapos = 20;
    // profit of dwarfsoldier
    uint256 public profitOfDwarfSoldier = 10;

    /**
     * @param _dwarfs_nft reference to the Dwarfs_NFT NFT contract
     * @param _god reference to the $GOD token
     */
    constructor(address _dwarfs_nft, address _god) {
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
            if (_msgSender() != address(dwarfs_nft)) {
                // dont do this step if its a mint + stake
                require(
                    dwarfs_nft.ownerOf(tokenIds[i]) == _msgSender(),
                    "AINT YO TOKEN"
                );
                require(
                    getCityId(tokenIds[i]) < MAX_NUM_CITY,
                    "CITY LIMIT ERROR"
                );

                dwarfs_nft.transferFrom(
                    _msgSender(),
                    address(this),
                    tokenIds[i]
                );
            } else if (tokenIds[i] == 0) {
                continue; // there may be gaps in the array for stolen tokens
            }

            _addToCity(account, tokenIds[i]);
        }
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
     * get the god amount of a token
     * @param tokenId the ID of the token to get the god amount
     * @return godAmount - god amount of merchant
     */
    function getGod(uint256 tokenId) public view returns (uint256 godAmount) {
        IDwarfs_NFT.DwarfTrait memory t = dwarfs_nft.getTokenTraits(tokenId);
        return t.god;
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
     * adds a single token to the city
     * @param account the address of the staker
     * @param tokenId the ID of the Merchant to add to the Clan
     */
    function _addToCity(address account, uint256 tokenId)
        internal
        whenNotPaused
        _updateEarnings
    {
        uint8 cityId = getCityId(tokenId);
        cities[cityId].push(
            Stake({
                owner: account,
                tokenId: uint16(tokenId),
                value: uint80(block.timestamp)
            })
        );

        emit TokenStaked(account, tokenId, block.timestamp);
    }

    /** CLAIMING / UNSTAKING */

    /**
     * realize $GOD earnings and optionally unstake tokens from the Clan (Cities)
     * to unstake a Merchant it will require it has 2 days worth of $GOD unclaimed
     * @param tokenIds the IDs of the tokens to claim earnings from
     */
    function claimManyFromClan(uint16[] calldata tokenIds)
        external
        whenNotPaused
        _updateEarnings
    {
        uint256 owed = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (isMerchant(tokenIds[i]))
                owed += _claimMerchantFromCity(tokenIds[i]);
            else owed += _claimMobsterFromCity(tokenIds[i]);
        }

        if (owed == 0) return;
        god.mint(_msgSender(), owed);
    }

    function claimManyFromClanByCity(uint8 cityId)
        external
        whenNotPaused
        _updateEarnings
    {
        require(cities[cityId].length > 0, "Empty City");
        uint16[] memory tokenIds = new uint16[](cities[cityId].length);
        for (uint256 i = 0; i < cities[cityId].length; i++) {
            tokenIds[i] = cities[cityId][i].tokenId;
        }

        uint256 owed = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (isMerchant(tokenIds[i]))
                owed += _claimMerchantFromCity(tokenIds[i]);
            else owed += _claimMobsterFromCity(tokenIds[i]);
        }

        cityPots[cityId] = 0;
        if (owed == 0) return;
        god.mint(_msgSender(), owed);
    }

    /**
     * realize $GOD earnings for a single Merchant and optionally unstake it
     * if not unstaking, pay a 20% tax to the staked Mobsters
     * if unstaking, there is a 50% chance all $GOD is stolen
     * @param tokenId the ID of the Merchant to claim earnings from
     * @return owed - the amount of $GOD earned
     */
    function _claimMerchantFromCity(uint256 tokenId)
        internal
        returns (uint256 owed)
    {
        uint8 cityId = getCityId(tokenId);
        uint256 godAmount = getGod(tokenId);
        Stake memory stake = cities[cityId][tokenId];
        require(stake.owner == _msgSender(), "SWIPER, NO SWIPING");

        if (totalGodEarned < MAXIMUM_GLOBAL_GOD) {
            owed =
                (((block.timestamp - stake.value) *
                    godAmount *
                    DAILY_GOD_RATE) / 100) /
                1 days;
        } else if (stake.value > lastClaimTimestamp) {
            owed = 0; // $WOOL production stopped already
        } else {
            owed =
                (((lastClaimTimestamp - stake.value) *
                    godAmount *
                    DAILY_GOD_RATE) / 100) /
                1 days; // stop earning additional $WOOL if it's all been earned
        }

        if (false) {
            // risky game
            if (random(tokenId) & 1 == 1) {
                // 50%
                owed = 0;
            }
        } else {
            cityPots[cityId] += (owed * GOD_CLAIM_TAX_PERCENTAGE) / 100;
            cities[cityId][tokenId] = Stake({
                owner: _msgSender(),
                tokenId: uint16(tokenId),
                value: uint80(block.timestamp)
            }); // reset stake
        }

        // Not implemented yet
        emit MerchantClaimed(tokenId, owed);
    }

    /**
     * realize $GOD earnings for a single Mobster and optionally unstake it
     * Mobsters earn $GOD proportional to their Alpha rank
     * @param tokenId the ID of the Mobster to claim earnings from
     * @return owed - the amount of $GOD earned
     */
    function _claimMobsterFromCity(uint256 tokenId)
        internal
        returns (uint256 owed)
    {
        require(
            dwarfs_nft.ownerOf(tokenId) == address(this),
            "AINT A PART OF THE PACK"
        );

        uint8 alpha = getAlpha(tokenId);
        uint8 cityId = getCityId(tokenId);
        if (alpha == 5) {
            owed += (cityPots[cityId] * profitOfDwarfSoldier) / 100;
        } else if (alpha == 6) {
            owed += (cityPots[cityId] * profitOfDwarfCapos) / 100;
        } else if (alpha == 7) {
            owed += (cityPots[cityId] * profitOfBoss) / 100;
        } else if (alpha == 8) {
            owed += (cityPots[cityId] * profitOfDwarfather) / 100;
        }

        // Not implemented yet
        emit MobsterClaimed(tokenId, owed);
    }

    /**
     * tracks $GOD earnings to ensure it stops once 2.4 billion is eclipsed
     */
    modifier _updateEarnings() {
        if (totalGodEarned < MAXIMUM_GLOBAL_GOD) {
            totalGodEarned +=
                ((block.timestamp - lastClaimTimestamp) *
                    totalMerchantStaked *
                    DAILY_GOD_RATE) /
                1 days;
            lastClaimTimestamp = block.timestamp;
        }
        _;
    }

    /** ADMIN */
    /**
     * enables owner to pause / unpause minting
     */
    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    /* Get the available city id */
    function getAvailableCity() external view returns (uint8) {
        for (uint8 i = 0; i < MAX_NUM_CITY; i++) {
            if (cities[i].length < 200) {
                return i;
            }
        }

        return 0;
    }

    /* Get the number of dwarfather in city */
    function getNumDwarfather(uint8 cityId) external view returns (uint16) {
        uint16 res = 0;
        for (uint16 i = 0; i < cities[cityId].length; i++) {
            if (
                dwarfs_nft
                    .getTokenTraits(cities[cityId][i].tokenId)
                    .alphaIndex == 8
            ) {
                res++;
            }
        }

        return res;
    }

    /* Get the number of boss in city */
    function getNumBoss(uint8 cityId) external view returns (uint16) {
        uint16 res = 0;
        for (uint16 i = 0; i < cities[cityId].length; i++) {
            if (
                dwarfs_nft
                    .getTokenTraits(cities[cityId][i].tokenId)
                    .alphaIndex == 7
            ) {
                res++;
            }
        }

        return res;
    }

    /* Get the number of dwarfcapos in city */
    function getNumDwarfCapos(uint8 cityId) external view returns (uint16) {
        uint16 res = 0;
        for (uint16 i = 0; i < cities[cityId].length; i++) {
            if (
                dwarfs_nft
                    .getTokenTraits(cities[cityId][i].tokenId)
                    .alphaIndex == 6
            ) {
                res++;
            }
        }

        return res;
    }

    /* Get the number of dwarfsoldier in city */
    function getNumDwarfSoldier(uint8 cityId) external view returns (uint16) {
        uint16 res = 0;
        for (uint16 i = 0; i < cities[cityId].length; i++) {
            if (
                dwarfs_nft
                    .getTokenTraits(cities[cityId][i].tokenId)
                    .alphaIndex == 5
            ) {
                res++;
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
        return IERC721Receiver.onERC721Received.selector;
    }
}
