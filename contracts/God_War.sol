// SPDX-License-Identifier: NO LICENSE  

pragma solidity ^0.8.0;

import "./Dwarfs_NFT.sol";
import "./GOD.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol";

/// @title God_War
/// @author Bounyavong
/// @dev God_War logic is implemented and this is the upgradeable
contract God_War is 
  Initializable, 
  OwnableUpgradeable, 
  PausableUpgradeable
{

  // Represents the current state of each clan, one per dwarfather
  struct Clan {
    bool enabled;
    uint80 lastUpdated; 
    uint32 protection;
    uint256 tokenValue;
    uint256 score;
    uint256 tokenValueSeconds;
    uint256 god;
    uint256 balance;
    uint256 godSeconds;
    uint256 guaranteedRewards;
  }

  // Represents the state of a single NFT's stake
  struct TokenStake {
    uint32 clan;
    uint80 lastUpdated;
    address owner;
  }

  // Represents the state of an address' total GOD staked in a clan
  struct GodStake {
    uint256 god;
    uint80 lastUpdated;
    uint256 godSeconds;
  }

  // Emitted when NFTs are staked
  event TokensStaked(
    address owner,
    uint32[] tokenIds,
    uint32 clan
  );

  // Emitted when NFTs are unstaked
  event TokensUnstaked(
    address owner,
    uint32[] tokenIds
  );

  // Emitted when GOD is staked
  event GodStaked(
    address owner,
    uint32 clan,
    uint256 amount
  );

  // Emitted when GOD is unstaked
  event GodUnstaked(
    address owner,
    uint32 clan,
    uint256 amount
  );

  // Emitted when NFTs claim their rewards
  event TokenRewardsClaimed(
    address owner,
    uint32[] tokenIds,
    uint256 reward
  );

  // Emitted when rewards for GOD stakes are claimed
  event GodRewardsClaimed(
    address owner,
    uint256 reward
  );

  // Emitted when a clan vendettas another one
  event ClanVendetta(
    uint32 clan,
    uint32 target
  );

  // Emitted when a clan protects itself
  event ClanDefended(
    uint32 clan
  );

  bool public bStartClans;
  // timestamp of when game is ended to calculate seconds staked for each token
  uint256 public gameEndTimestamp;
  // array of percentages each team wins (1st -> last)
  uint256[] public winningPercentages;

  // points each Influence point of a mobster earns per second
  uint256[] public dwarfPointUnits;
  // mapping from Dwarfather ID to its clan's state
  mapping(uint32 => Clan) public clans;
  // mapping from Token ID to its stake
  mapping(uint32 => TokenStake) public tokenStakes;
  // mapping from clan to owner to GOD stake
  mapping(uint32 => mapping(address => GodStake)) public godStakes;
  // array of all the dwarfather's IDs
  uint32[] public dwarfathers;
  // mapping from Dwarfather ID to its placement at the end of the game (1st, 2nd, ..., last)
  mapping(uint32 => uint256) public rankings;

  // total GOD available to be won in the game
  uint256 public WINNER_POT;
  // percentage of clan's winnings an Dwarfather receives
  uint256 public constant DWARFATHER_PERCENTAGE = 5;

  // percentage of points lost if vendettaed without protection
  uint128 public constant VENDETTA_LOSS = 3;
  // maximum level a mobster can have
  uint8 public constant MAX_LEVEL = 8;

  // reference to dwarfs
  Dwarfs_NFT public dwarfs_nft;

  // reference to GOD
  GOD public god;

  /** 
   * initializes contract
   * @param _dwarfs_nft reference to Dwarfs_NFT
   * @param _god reference to God
   */
  function initialize(
    address _dwarfs_nft, 
    address _god
  ) external initializer {
    __Ownable_init();
    __Pausable_init();

    dwarfs_nft = Dwarfs_NFT(_dwarfs_nft);
    god = GOD(_god);

    _pause();

    winningPercentages = [1980, 1555, 1180, 955, 765, 615, 515, 440, 365, 340, 315, 290, 265, 240, 180];
    dwarfPointUnits = [20, 20, 20, 20, 20, 40, 70, 140, 0];

    WINNER_POT = 1810000000 ether;
    gameEndTimestamp = 0;
    bStartClans = true;
  }

  /** EXTERNAL */

  /**
   * accounts for dwarfs in the clan
   * will start a clan for an dwarfather if it is passed in (clan must equal the dwarfather's ID)
   * @param tokenIds the IDs of the dwarfs to stake
   * @param clan the clan to join
   */
  function joinClan(uint32[] calldata tokenIds, uint32 clan) external whenNotPaused {
    require(gameEndTimestamp == 0, "GAME HAS ENDED");
    require(tokenIds.length > 0, "GOTTA STAKE SOMETHING");
    _updateClan(clan);
    for (uint i = 0; i < tokenIds.length; i++) {
      _joinClan(tokenIds[i], clan);
    }
    
    emit TokensStaked(_msgSender(), tokenIds, clan);
  }

  /**
   * adds a single dwarf to a clan
   * @param tokenId the ID of the migrated dwarf to stake
   * @param clan the clan to join
   */
  function _joinClan(uint32 tokenId, uint32 clan) internal {
    require(dwarfs_nft.ownerOf(tokenId) == _msgSender(), "AINT YO TOKEN");

    if (_levelOfDwarf(tokenId) == MAX_LEVEL) {
      require(bStartClans, "STARTING A CLAN IS DISABLED");
      require(clan == tokenId, "YOURE AN DWARFATHER. START YOUR OWN CLAN");
      dwarfathers.push(tokenId);
      clans[tokenId].enabled = true;
    }

    require(clans[clan].enabled, "NOT A CLAN");

    // redundant sanity check
    require(tokenStakes[tokenId].owner == address(0x0), "ALREADY IN A CLAN");
    tokenStakes[tokenId] = TokenStake({
      clan: uint16(clan),
      lastUpdated: uint80(block.timestamp),
      owner: _msgSender()
    });

    clans[clan].tokenValue += dwarfPointUnits[_levelOfDwarf(tokenId)];
  }

  /**
   * moves dwarfs from one clan to another without moving the ERC721 and resets the stake
   * @param tokenIds the IDs of the dwarfs to transfer
   * @param newClan the clan to move them to
   */
  function transferClan(uint32[] calldata tokenIds, uint32 newClan) external whenNotPaused {
    require(gameEndTimestamp == 0, "GAME HAS ENDED");
    require(clans[newClan].enabled, "NOT A CLAN");
    require(tokenIds.length > 0, "GOTTA TRANSFER SOMETHING");
    _updateClan(newClan);
    for (uint i = 0; i < tokenIds.length; i++) {
      _transferClan(tokenIds[i], newClan);
    }

    // operates indentically to an unstake + a stake
    emit TokensUnstaked(_msgSender(), tokenIds);
    emit TokensStaked(_msgSender(), tokenIds, newClan);
  }

  /**
   * moves a single dwarf from one clan to another without moving the ERC721 and resets the stake
   * @param tokenId the ID of the migrated dwarf to transfer
   * @param newClan the clan to move it to
   */
  function _transferClan(uint32 tokenId, uint32 newClan) internal {
    uint256 level = _levelOfDwarf(tokenId);
    require(level != MAX_LEVEL, "DWARFATHERS CANT LEAVE THEIR CLAN");
    TokenStake storage stake = tokenStakes[tokenId];
    require(stake.owner == _msgSender(), "AINT YO TOKEN");
    require(stake.clan != newClan, "CANT TRANSFER TO SAME CLAN");
    _updateClan(stake.clan);
    clans[stake.clan].tokenValue -= dwarfPointUnits[level];

    // no need to delete the stake, just update it
    stake.clan = uint16(newClan); // change clan
    stake.lastUpdated = uint80(block.timestamp); // reset time staked

    // no need to update the new clan here, was done before the loop
    clans[newClan].tokenValue += dwarfPointUnits[level];
  }

  /**
   * returns dwarfs from the contract and resets their stakes
   * @param tokenIds the IDs of the dwarfs to unstake
   */
  function leaveClan(uint32[] calldata tokenIds) external whenNotPaused {
    require(gameEndTimestamp == 0, "GAME HAS ENDED");
    require(tokenIds.length > 0, "GOTTA TRANSFER SOMETHING");
    for (uint i = 0; i < tokenIds.length; i++) {
      _leaveClan(tokenIds[i]);
    }

    emit TokensUnstaked(_msgSender(), tokenIds);
  }

  function _leaveClan(uint32 tokenId) internal {
    require(tokenStakes[tokenId].owner == _msgSender(), "AINT YO TOKEN");
    uint32 clan = tokenStakes[tokenId].clan;
    require(clan != 0x0, "AINT WITH A CLAN");
    require(_levelOfDwarf(tokenId) != MAX_LEVEL, "DWARFATHERS CANT LEAVE THEIR CLAN");
    // we must call this on each one since it's possible to
    // unstake from multiple clans in a single call
    _updateClan(clan);

    delete tokenStakes[tokenId];
    clans[clan].tokenValue -= dwarfPointUnits[_levelOfDwarf(tokenId)];
  }

  /**
   * sends GOD from user and creates a stake for the owner
   * @param clan the clan to stake the GOD in
   * @param amount the amount of GOD to stake
   */
  function stakeGod(uint32 clan, uint256 amount) external whenNotPaused {
    require(gameEndTimestamp == 0, "GAME HAS ENDED");
    require(clans[clan].enabled, "MUST STAKE IN A CLAN");
    require(amount > 0, "GOTTA STAKE SOMETHING");
    _updateClan(clan);
    GodStake storage stake = godStakes[clan][_msgSender()];
    uint256 elapsed = block.timestamp - stake.lastUpdated;
    stake.godSeconds += elapsed * stake.god; // god is 0 on first stake
    stake.lastUpdated = uint80(block.timestamp);
    stake.god += uint176(amount);
    clans[clan].god += amount;

    // burn here to circumvent the need for an approval
    // side effect: GOD contract's totalSupply() will be affected through the duration of the game
    god.burn(_msgSender(), amount); 

    emit GodStaked(_msgSender(), clan, amount);
  }

  /**
   * transfers all staked GOD from one clan to another and resets godSeconds
   * @param oldClan the clan to move the GOD from
   * @param newClan the clan to move the GOD to
   */
  function transferGod(uint32 oldClan, uint32 newClan) external whenNotPaused {
    require(gameEndTimestamp == 0, "GAME HAS ENDED");
    require(clans[newClan].enabled, "MUST STAKE IN A CLAN");
    require(oldClan != newClan, "CANT TRANSFER TO SAME CLAN");
    GodStake storage oldStake = godStakes[oldClan][_msgSender()];
    require(oldStake.god > 0, "GOTTA TRANSFER SOMETHING");
    _updateClan(oldClan);
    clans[oldClan].god -= oldStake.god;

    _updateClan(newClan);
    clans[newClan].god += oldStake.god;

    GodStake storage newStake = godStakes[newClan][_msgSender()];
    // update the new stake if necessary
    uint256 elapsed = block.timestamp - newStake.lastUpdated;
    newStake.godSeconds += elapsed * newStake.god; // god is 0 on first stake
    newStake.lastUpdated = uint80(block.timestamp);
    newStake.god += oldStake.god;

    emit GodUnstaked(_msgSender(), oldClan, oldStake.god);
    emit GodStaked(_msgSender(), newClan, oldStake.god);

    delete godStakes[oldClan][_msgSender()];
  }

  /**
   * sends all GOD staked in a clan back to owner and resets the stake
   * @param clan the clan to unstake from
   */
  function unstakeGod(uint32 clan) external whenNotPaused {
    require(gameEndTimestamp == 0, "GAME HAS ENDED");
    _updateClan(clan);
    uint256 staked = godStakes[clan][_msgSender()].god;
    require(staked > 0, "GOTTA UNSTAKE SOMETHING");
    clans[clan].god -= staked;
    delete godStakes[clan][_msgSender()];

    // we burned the GOD during stakeGod to save an approval
    // here we are minting it back to the owner
    god.mint(_msgSender(), staked);

    emit GodUnstaked(_msgSender(), clan, staked);
  }

  /**
   * decrements the protection of the target or reduces their score by VENDETTA_LOSS % if protection is 0
   * @param dwarfatherId the ID of the Dwarfather vendetta
   * @param target the ID of the clan to vendetta
   */
  function vendetta(uint32 dwarfatherId, uint32 target) external whenNotPaused {
    require(gameEndTimestamp == 0, "GAME HAS ENDED");
    require(clans[dwarfatherId].enabled, "YOURE NOT A CLAN LEADER");
    require(dwarfatherId != target, "CANT VENDETTA YOURSELF");
    require(tokenStakes[dwarfatherId].owner == _msgSender(), "AINT YO TOKEN");
    require(clans[target].enabled, "NOT A VALID TARGET");

    _updateClan(dwarfatherId); // account for any earned balance
    require(clans[dwarfatherId].balance > vendettaCost(dwarfatherId), "INSUFFICIENT BALANCE TO VENDETTA");
    clans[dwarfatherId].balance = 0; // discharge all accrued godSeconds
    _updateClan(target); // get the latest score

    emit ClanVendetta(dwarfatherId, target);

    // if the target has protections, decrement
    if (clans[target].protection > 0) {
      clans[target].protection -= 1;
    } else { // otherwise, reduce their score
      clans[target].score = clans[target].score * (100 - VENDETTA_LOSS) / 100;
    }
  }

  /**
   * increments the clans protection count
   * @param dwarfatherId the ID of the Dwarfather protecting
   */
  function protect(uint32 dwarfatherId) external whenNotPaused {
    require(gameEndTimestamp == 0, "GAME HAS ENDED");
    require(clans[dwarfatherId].enabled, "YOURE NOT A CLAN LEADER");
    require(tokenStakes[dwarfatherId].owner == _msgSender(), "AINT YO TOKEN");
    _updateClan(dwarfatherId); // account for any earned balance
    require(clans[dwarfatherId].balance > protectionCost(dwarfatherId), "INSUFFICIENT BALANCE TO DEFEND");
    clans[dwarfatherId].protection += 1; 
    clans[dwarfatherId].balance = 0; // discharge all accrued godSeconds

    emit ClanDefended(dwarfatherId);
  }

  /**
   * claims GODs for the earned rewards for dwarfs
   * @param tokenIds the IDs of the dwarfs to claim for
   */
  function claimTokens(uint32[] calldata tokenIds) external whenNotPaused {
    require(gameEndTimestamp > 0, "GAME HAS NOT ENDED");
    require(tokenIds.length > 0, "GOTTA CLAIM SOMETHING");
    uint256 won;
    for (uint i = 0; i < tokenIds.length; i++) {
      won += _claimToken(tokenIds[i]); // will return each token back
    }

    _mintReward(won); // mint the rewards
    emit TokenRewardsClaimed(_msgSender(), tokenIds, won);
  }

  /** 
   * calculates the winnings for a dwarf and returns it to the owner
   * @param tokenId the ID of the dwarf to claim
   */
  function _claimToken(uint32 tokenId) internal returns (uint256 won) {
    require(_msgSender() == tokenStakes[tokenId].owner, "AINT YO TOKEN");

    won = _tokenWinnings(tokenId);

    delete tokenStakes[tokenId];
  }

  /**
   * claims GODs for the earned rewards for all GOD staked across all clans
   */
  function claimGod() external whenNotPaused {
    require(gameEndTimestamp > 0, "GAME HAS NOT ENDED");
    uint256 godStaked;
    uint256 won;
    for (uint i = 0; i < dwarfathers.length; i++) { // loop through every clan
      if (godStakes[dwarfathers[i]][_msgSender()].god == 0) continue; // check for a stake
      godStaked += godStakes[dwarfathers[i]][_msgSender()].god;
      won += _godWinnings(dwarfathers[i], _msgSender());
      delete godStakes[dwarfathers[i]][_msgSender()]; // if called again, god will be 0
    }
    require(godStaked > 0, "GOTTA CLAIM SOMETHING");
    god.mint(_msgSender(), godStaked); // return their staked god via a mint - see stakeGod()

    if (won > 0) {
      _mintReward(won);
      emit GodRewardsClaimed(_msgSender(), won);
    }
  }

  /**
   * send GODs to a user depending on their earnings
   */
  function _mintReward(uint256 amount) internal {
      god.mint(_msgSender(), amount);
  }

  /**
   * cost (in god seconds) to vendetta
   * @param dwarfatherId the ID of the Dwarfather vendetta
   */
  function vendettaCost(uint32 dwarfatherId) public view returns (uint128) {
    // if less than the equivalent of 50 merchant are staked
    // require a minimum balance
    return clans[dwarfatherId].tokenValue < 50 * dwarfPointUnits[0] 
      ? 3000000 ether * 1 days // 3000 * 50 * 20
      : 3000 ether * 1 days * uint128(clans[dwarfatherId].tokenValue);
  }

  /**
   * cost (in god seconds) to protect
   * @param dwarfatherId the ID of the Dwarfather protecting
   */
  function protectionCost(uint32 dwarfatherId) public view returns (uint128) {
    // if less than the equivalent of 50 merchant are staked
    // require a minimum balance
    return clans[dwarfatherId].tokenValue < 50 * dwarfPointUnits[0] 
      ? 3000000 ether * 1 days // 3000 * 50 * 20
      : 3000 ether * 1 days * uint128(clans[dwarfatherId].tokenValue);
  }

  function godWinnings(address owner) public view returns (uint256) {
    require(gameEndTimestamp > 0, "GAME HAS NOT ENDED");
    uint256 won;
    for (uint i = 0; i < dwarfathers.length; i++) { // loop through every clan
      if (godStakes[dwarfathers[i]][owner].god == 0) continue; // check for a stake
      won += _godWinnings(dwarfathers[i], owner);
    }
    return won;
  }

  /** INTERNAL */

  function _isMerchant(uint32 tokenId) internal view returns (bool merchant) {
    merchant = dwarfs_nft.getTokenTraits(tokenId).isMerchant;
  }

  function _levelOfDwarf(uint32 tokenId) internal view returns (uint8 level) {
    level = dwarfs_nft.getTokenTraits(tokenId).level;
  }

  /**
   * updates accounting for a single clan
   * @param clan the clan to update accounting for
   */
  function _updateClan(uint32 clan) internal {
    // if the game is over, no changes should be made
    if (gameEndTimestamp > 0) return;
    Clan storage p = clans[clan];
    uint256 elapsed = block.timestamp - p.lastUpdated;
    // if called multiple times in a block, no need to recalculate
    if (elapsed == 0) return;

    // score is increased by token values x time
    p.score += p.tokenValue * elapsed;
    // tokenValueSeconds is ncreased by token values x time
    p.tokenValueSeconds += p.tokenValue * elapsed;
    // balance is increased by god x time
    p.balance += p.god * elapsed;
    // godSeconds is increased by god x time
    p.godSeconds += p.god * elapsed;
    p.lastUpdated = uint80(block.timestamp);
  }

  /**
   * calculates the winnings for a single dwarf
   * half of the clan's winnings are made available for dwarfs to claim
   * @param tokenId the ID of the token to calculate winnings for
   */
  function _tokenWinnings(uint32 tokenId) internal view returns (uint256) {
    if (tokenStakes[tokenId].owner == address(0x0)) return 0;
    uint32 clan = tokenStakes[tokenId].clan;
    uint256 elapsed = gameEndTimestamp - tokenStakes[tokenId].lastUpdated;
    if (_isMerchant(tokenId))
      return dwarfPointUnits[0] * elapsed * _clanWinnings(clan) * (100 - DWARFATHER_PERCENTAGE) / 100 / clans[clan].tokenValueSeconds / 2;
    uint8 level = _levelOfDwarf(tokenId);
    if (level != MAX_LEVEL)
      return dwarfPointUnits[level] * elapsed * _clanWinnings(clan) * (100 - DWARFATHER_PERCENTAGE) / 100 / clans[clan].tokenValueSeconds / 2;
    else
      return _clanWinnings(clan) * DWARFATHER_PERCENTAGE / 100; // DWARFATHER WINS % CLAN POT
  }

  /**
   * calculates the winnings for a GOD stake
   * half of the clan's winnings are made available for god stakes to claim
   * @param clan the clan to calculate GOD winnings for
   */
  function _godWinnings(uint32 clan, address owner) internal view returns (uint256) {
    if (godStakes[clan][owner].god == 0) return 0;
    uint256 elapsed = gameEndTimestamp - godStakes[clan][owner].lastUpdated;
    uint256 godSeconds = godStakes[clan][owner].godSeconds + godStakes[clan][owner].god * elapsed;
    // DWARFATHER_PERCENTAGE is taken off to account for it being earned in _tokenWinnings
    return godSeconds * _clanWinnings(clan) * (100 - DWARFATHER_PERCENTAGE) / clans[clan].godSeconds / 200;
  }
  
  /**
   * calculates the entire clan's winnings at the end of the game
   * @param clan the clan to calculate winnings for
   */
  function _clanWinnings(uint32 clan) internal view returns (uint256) {
    return winningPercentages[rankings[clan] - 1] * WINNER_POT / 10000 + clans[clan].guaranteedRewards;
  }

  /** ADMIN */

  /**
   * allows owner to guarantee a reward to a specific clan
   * used for surprises and possible checkpoint winnings
   * total pot will never eclipse original pot size
   * @param clan the clan to guarantee rewards for
   * @param amount the amount to guarantee
   */
  function setGuaranteedRewards(uint32 clan, uint256 amount) external onlyOwner {
    WINNER_POT = WINNER_POT + clans[clan].guaranteedRewards - amount;
    clans[clan].guaranteedRewards = amount;
  }

  /**
   * finalizes the end of the game
   */
  function endGame() external onlyOwner {
    require(gameEndTimestamp == 0, "GAME HAS ENDED");
    uint256 length = dwarfathers.length;
    uint256 place;
    uint256 j;
    uint256 max;
    uint32 mobster;
    uint256 current;
    // update every clan for the final time
    for (j = 0; j < length; j++) {
      _updateClan(dwarfathers[j]);
    }

    // sort the clans into winning order (clan -> placement)
    for (place = 1; place <= length; place++) {
      max = 0;
      for (j = 0; j < length; j++) {
        if (rankings[dwarfathers[j]] != 0) continue;
        current = clans[dwarfathers[j]].score;
        if (current > max) {
          max = current;
          mobster = dwarfathers[j];
        }
      }
      rankings[mobster] = place;
    }

    // the games final calculations for earnings are based off this time
    gameEndTimestamp = block.timestamp;
  }

  /**
   * enables owner to pause / unpause minting
   */
  function setPaused(bool _p) external onlyOwner {
    if (_p) _pause();
    else _unpause();
  }

  /**
   * enables owner to enable / disable new clans from being started
   */
  function setbStartClans(bool _a) external onlyOwner {
    bStartClans = _a;
  }
}