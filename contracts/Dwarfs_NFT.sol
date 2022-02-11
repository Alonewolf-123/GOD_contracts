// SPDX-License-Identifier: MIT LICENSE

pragma solidity ^0.8.0;
import "./Ownable.sol";
import "./Pausable.sol";
import "./IDwarfs_NFT.sol";
import "./IClan.sol";
import "./GOD.sol";
import "./Strings.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract Dwarfs_NFT is ERC721Upgradeable, IDwarfs_NFT, Ownable, Pausable {
    using Strings for uint256;

    // mint price
    uint256 public MINT_ETH_PRICE_0 = 0.0012 ether;
    uint256 public MINT_ETH_PRICE_1 = 0.0014 ether;
    uint256 public MINT_ETH_PRICE_2 = 0.0016 ether;
    uint256 public MINT_ETH_PRICE_3 = 0.0018 ether;

    uint256 public MINT_GOD_PRICE_0 = 0 ether;
    uint256 public MINT_GOD_PRICE_1 = 100000 ether;
    uint256 public MINT_GOD_PRICE_2 = 120000 ether;
    uint256 public MINT_GOD_PRICE_3 = 140000 ether;

    uint256 public MAX_GEN0_TOKENS = 8000;
    uint256 public MAX_GEN1_TOKENS = 12000;
    uint256 public MAX_GEN2_TOKENS = 16000;

    // max number of tokens that can be minted - 20000 in production
    uint256 public MAX_TOKENS = 20000;

    // sold amount percent by eth (50%)
    uint256 public MAX_TOKENS_ETH_SOLD = 50;

    // number of mobsters in a city
    uint8 public MAX_DWARFSOLDIER = 150;
    uint8 public MAX_DWARFCAPOS = 45;
    uint8 public MAX_BOSS = 4;
    uint8 public MAX_DWARFATHER = 1;

    // number of tokens have been minted so far
    uint16 public minted;

    // mapping from tokenId to a struct containing the token's traits
    mapping(uint256 => DwarfTrait) public tokenTraits;
    // mapping from hashed(tokenTrait) to the tokenId it's associated with
    // used to ensure there are no duplicates
    mapping(uint256 => uint256) public existingCombinations;

    // reference to the Clan for choosing random Mobster thieves
    IClan public clan;
    // reference to $GOD for burning on mint
    GOD public god;

    // traits parameters range
    uint8 public MAX_BACKGROUND = 255; // background
    uint8 public MAX_WEAPON = 255; // weapon
    uint8 public MAX_BODY = 255; // body
    uint8 public MAX_OUTFIT = 255; // outfit
    uint8 public MAX_HEAD = 255; // head
    uint8 public MAX_MOUTH = 255; // mouth
    uint8 public MAX_EYES = 255; // eyes
    uint8 public MAX_NOSE = 255; // nose
    uint8 public MAX_EYEBROWS = 255; // eyebrows
    uint8 public MAX_HAIR = 255; // hair
    uint8 public MAX_EYEWEAR = 255; // eyewear
    uint8 public MAX_FACIALHAIR = 255; // facialhair
    uint8 public MAX_EARS = 255; // ears

    // Base URI
    string private baseURI;

    // temporary variables
    // (city id, number of dwarfather, number of boss, number of dwarfcapos, number of dwarfsoldier)
    uint8 private cityId;
    uint16 private dwarfather;
    uint16 private boss;
    uint16 private dwarfcapos;
    uint16 private dwarfsoldier;

    /**
     * instantiates contract and rarity tables
     */
    function initialize(address _god) public virtual initializer {
        __ERC721_init("Game Of Dwarfs", "DWARF");
        god = GOD(_god);
    }

    /** EXTERNAL */
    /**
     * mint a token by owner
     */
    function mintByOwner(uint256 amount, DwarfTrait memory s)
        external
        onlyOwner
    {
        require(
            existingCombinations[structToHash(s)] == 0,
            "DwarfTrait already exist."
        );

        for (uint256 i = 0; i < amount; i++) {
            minted++;
            tokenTraits[minted] = s;
            _safeMint(_msgSender(), minted);
        }
    }

    /**
     * mint a token - 85% Merchant, 15% Mobsters
     */
    function mint(uint256 amount, bool stake) external payable whenNotPaused {
        require(tx.origin == _msgSender(), "Only EOA");
        require(minted + amount <= MAX_TOKENS, "All tokens minted");
        require(amount > 0 && amount <= 30, "Invalid mint amount");
        if (minted < MAX_GEN0_TOKENS) {
            require(
                minted + amount <= MAX_GEN0_TOKENS,
                "All tokens on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICE_0 <= msg.value,
                "Invalid payment amount"
            );
        } else if (
            minted > MAX_GEN0_TOKENS &&
            minted <
            MAX_GEN0_TOKENS +
                ((MAX_GEN1_TOKENS - MAX_GEN0_TOKENS) * MAX_TOKENS_ETH_SOLD) /
                100
        ) {
            require(
                minted + amount <=
                    MAX_GEN0_TOKENS +
                        ((MAX_GEN1_TOKENS - MAX_GEN0_TOKENS) *
                            MAX_TOKENS_ETH_SOLD) /
                        100,
                "All tokens on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICE_1 <= msg.value,
                "Invalid payment amount"
            );
        } else if (
            minted > MAX_GEN1_TOKENS &&
            minted <
            MAX_GEN1_TOKENS +
                ((MAX_GEN2_TOKENS - MAX_GEN1_TOKENS) * MAX_TOKENS_ETH_SOLD) /
                100
        ) {
            require(
                minted + amount <=
                    MAX_GEN1_TOKENS +
                        ((MAX_GEN2_TOKENS - MAX_GEN1_TOKENS) *
                            MAX_TOKENS_ETH_SOLD) /
                        100,
                "All tokens on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICE_2 <= msg.value,
                "Invalid payment amount"
            );
        } else if (
            minted > MAX_GEN2_TOKENS &&
            minted <
            MAX_GEN2_TOKENS +
                ((MAX_TOKENS - MAX_GEN2_TOKENS) * MAX_TOKENS_ETH_SOLD) /
                100
        ) {
            require(
                minted + amount <=
                    MAX_GEN2_TOKENS +
                        ((MAX_TOKENS - MAX_GEN2_TOKENS) * MAX_TOKENS_ETH_SOLD) /
                        100,
                "All tokens on-sale already sold"
            );
            require(
                amount * MINT_ETH_PRICE_3 <= msg.value,
                "Invalid payment amount"
            );
        }

        uint256 totalGodCost = 0;
        uint16[] memory tokenIds = stake
            ? new uint16[](amount)
            : new uint16[](0);
        uint256 seed;

        for (uint256 i = 0; i < amount; i++) {
            if (i == 0 || clan.getAvailableCity() != cityId) {
                cityId = clan.getAvailableCity();
                dwarfather = clan.getNumDwarfather(cityId);
                boss = clan.getNumBoss(cityId);
                dwarfcapos = clan.getNumDwarfCapos(cityId);
                dwarfsoldier = clan.getNumDwarfSoldier(cityId);
            }

            minted++;
            seed = random(minted);
            DwarfTrait memory t = generate(minted, seed, stake);

            if (!stake || t.isMerchant) {
                _safeMint(_msgSender(), minted);
            } else {
                _safeMint(address(clan), minted);
                tokenIds[i] = minted;
            }
            totalGodCost += mintCost(minted);
        }

        if (totalGodCost > 0) god.burn(_msgSender(), totalGodCost);
        if (stake) clan.addManyToClan(_msgSender(), tokenIds);
    }

    /**
     * the first 8000 are paid in ETH
     * the next 2000 are paid in ETH
     * the next 2000 are 100,000 $GOD
     * the next 2000 are paid in ETH
     * the next 2000 are 120,000 $GOD
     * the next 2000 are paid in ETH
     * the next 2000 are 140,000 $GOD
     * @param tokenId the ID to check the cost of to mint
     * @return the cost of the given token ID
     */
    function mintCost(uint256 tokenId) public view returns (uint256) {
        if (tokenId <= MAX_GEN0_TOKENS) return MINT_GOD_PRICE_0;
        if (
            tokenId <=
            MAX_GEN0_TOKENS +
                ((MAX_GEN1_TOKENS - MAX_GEN0_TOKENS) * MAX_TOKENS_ETH_SOLD) /
                100
        ) return 0;
        if (tokenId <= MAX_GEN1_TOKENS) return MINT_GOD_PRICE_1;
        if (
            tokenId <=
            MAX_GEN1_TOKENS +
                ((MAX_GEN2_TOKENS - MAX_GEN1_TOKENS) * MAX_TOKENS_ETH_SOLD) /
                100
        ) return 0;
        if (tokenId <= MAX_GEN2_TOKENS) return MINT_GOD_PRICE_2;
        if (
            tokenId <=
            MAX_GEN2_TOKENS +
                ((MAX_TOKENS - MAX_GEN2_TOKENS) * MAX_TOKENS_ETH_SOLD) /
                100
        ) return 0;
        if (tokenId <= MAX_TOKENS) return MINT_GOD_PRICE_3;

        return 0 ether;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        // Hardcode the Clan's approval so that users don't have to waste gas approving
        if (_msgSender() != address(clan))
            require(
                _isApprovedOrOwner(_msgSender(), tokenId),
                "ERC721: transfer caller is not owner nor approved"
            );
        _transfer(from, to, tokenId);
    }

    /** INTERNAL */

    /**
     * generates traits for a specific token, checking to make sure it's unique
     * @param tokenId the id of the token to generate traits for
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t - a struct of traits for the given token ID
     */
    function generate(
        uint256 tokenId,
        uint256 seed,
        bool stake
    ) internal returns (DwarfTrait memory t) {
        t = selectTraits(seed, stake);

        if (tokenId <= MAX_GEN0_TOKENS) {
            t.generation = 0;
        } else if (tokenId > MAX_GEN0_TOKENS && tokenId <= MAX_GEN1_TOKENS) {
            t.generation = 1;
        } else if (tokenId > MAX_GEN1_TOKENS && tokenId <= MAX_GEN2_TOKENS) {
            t.generation = 2;
        } else {
            t.generation = 3;
        }

        if (existingCombinations[structToHash(t)] == 0) {
            tokenTraits[tokenId] = t;
            existingCombinations[structToHash(t)] = tokenId;
            return t;
        }

        if (t.alphaIndex == 5) {
            dwarfsoldier--;
        } else if (t.alphaIndex == 6) {
            dwarfcapos--;
        } else if (t.alphaIndex == 7) {
            boss--;
        } else if (t.alphaIndex == 8) {
            dwarfather--;
        }

        return generate(tokenId, random(seed), stake);
    }

    /**
     * selects the species and all of its traits based on the seed value
     * @param seed a pseudorandom 256 bit number to derive traits from
     * @return t -  a struct of randomly selected traits
     */
    function selectTraits(uint256 seed, bool stake)
        internal
        returns (DwarfTrait memory t)
    {
        t.isMerchant = (seed & 0xFFFF) % 100 >= 15;
        if (t.isMerchant == true || !stake) {
            t.alphaIndex = 0;
        } else {
            uint256 cur_seed = seed;

            t.cityId = cityId;
            while (true) {
                if (
                    (cur_seed & 0xFFFF) %
                        (MAX_DWARFATHER +
                            MAX_BOSS +
                            MAX_DWARFCAPOS +
                            MAX_DWARFSOLDIER) <
                    MAX_DWARFATHER
                ) {
                    if (dwarfather < MAX_DWARFATHER) {
                        t.alphaIndex = 8;
                        dwarfather++;
                        break;
                    }
                } else if (
                    (cur_seed & 0xFFFF) %
                        (MAX_DWARFATHER +
                            MAX_BOSS +
                            MAX_DWARFCAPOS +
                            MAX_DWARFSOLDIER) <
                    MAX_BOSS
                ) {
                    if (boss < MAX_BOSS) {
                        t.alphaIndex = 7;
                        boss++;
                        break;
                    }
                } else if (
                    (cur_seed & 0xFFFF) %
                        (MAX_DWARFATHER +
                            MAX_BOSS +
                            MAX_DWARFCAPOS +
                            MAX_DWARFSOLDIER) <
                    MAX_DWARFCAPOS
                ) {
                    if (dwarfcapos < MAX_DWARFCAPOS) {
                        t.alphaIndex = 6;
                        dwarfcapos++;
                        break;
                    }
                } else if (
                    (cur_seed & 0xFFFF) %
                        (MAX_DWARFATHER +
                            MAX_BOSS +
                            MAX_DWARFCAPOS +
                            MAX_DWARFSOLDIER) <
                    MAX_DWARFSOLDIER
                ) {
                    if (dwarfsoldier < MAX_DWARFSOLDIER) {
                        t.alphaIndex = 5;
                        dwarfsoldier++;
                        break;
                    }
                }
                cur_seed = random(cur_seed);
            }
        }

        // if Boss
        if (t.alphaIndex == 7) {
            // set the custom traits
            t.background_weapon = 0;
            t.body_outfit = 0;
            t.head_ears = 0;
            t.mouth_nose = 0;
            t.eyes_brows = 0;
            t.hair_facialhair = 0;
            t.eyewear = 0;
        } else {
            t.background_weapon =
                uint16((random(seed) % MAX_BACKGROUND) << 8) +
                uint8(random(seed + 1) % MAX_WEAPON);
            t.body_outfit =
                uint16((random(seed + 2) % MAX_BODY) << 8) +
                uint8(random(seed + 3) % MAX_OUTFIT);
            t.head_ears =
                uint16((random(seed + 4) % MAX_HEAD) << 8) +
                uint8(random(seed + 5) % MAX_EARS);
            t.mouth_nose =
                uint16((random(seed + 6) % MAX_MOUTH) << 8) +
                uint8(random(seed + 7) % MAX_NOSE);
            t.eyes_brows =
                uint16((random(seed + 8) % MAX_EYES) << 8) +
                uint8(random(seed + 9) % MAX_EYEBROWS);
            t.hair_facialhair =
                uint16((random(seed + 10) % MAX_HAIR) << 8) +
                uint8(random(seed + 11) % MAX_FACIALHAIR);
            t.eyewear = uint8(random(seed + 12) % MAX_EYEWEAR);
        }

        return t;
    }

    /**
     * converts a struct to a 256 bit hash to check for uniqueness
     * @param s the struct to pack into a hash
     * @return the 256 bit hash of the struct
     */
    function structToHash(DwarfTrait memory s) internal pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        s.isMerchant,
                        s.background_weapon,
                        s.body_outfit,
                        s.head_ears,
                        s.mouth_nose,
                        s.eyes_brows,
                        s.hair_facialhair,
                        s.eyewear,
                        s.cityId,
                        s.alphaIndex
                    )
                )
            );
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

    /** READ */
    function getTokenTraits(uint256 tokenId)
        external
        view
        override
        returns (DwarfTrait memory)
    {
        return tokenTraits[tokenId];
    }

    function getGen0Tokens() external view override returns (uint256) {
        return MAX_GEN0_TOKENS;
    }

    /** ADMIN */

    /**
     * called after deployment so that the contract can get random mobster thieves
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
     * updates the number of tokens for sale
     */
    function setGen0Tokens(uint256 _gen0Tokens) external onlyOwner {
        MAX_GEN0_TOKENS = _gen0Tokens;
    }

    function setGen1Tokens(uint256 _gen1Tokens) external onlyOwner {
        MAX_GEN1_TOKENS = _gen1Tokens;
    }

    function setGen2Tokens(uint256 _gen2Tokens) external onlyOwner {
        MAX_GEN2_TOKENS = _gen2Tokens;
    }

    function setGen3Tokens(uint256 _gen3Tokens) external onlyOwner {
        MAX_TOKENS = _gen3Tokens;
    }

    /* Set the ETH price */
    function setMintETHPrice0(uint256 _price) external onlyOwner {
        MINT_ETH_PRICE_0 = _price;
    }

    function setMintETHPrice1(uint256 _price) external onlyOwner {
        MINT_ETH_PRICE_1 = _price;
    }

    function setMintETHPrice2(uint256 _price) external onlyOwner {
        MINT_ETH_PRICE_2 = _price;
    }

    function setMintETHPrice3(uint256 _price) external onlyOwner {
        MINT_ETH_PRICE_3 = _price;
    }

    /* Set the GOD price */
    function setMintGODPrice0(uint256 _price) external onlyOwner {
        MINT_GOD_PRICE_0 = _price;
    }

    function setMintGODPrice1(uint256 _price) external onlyOwner {
        MINT_GOD_PRICE_1 = _price;
    }

    function setMintGODPrice2(uint256 _price) external onlyOwner {
        MINT_GOD_PRICE_2 = _price;
    }

    function setMintGODPrice3(uint256 _price) external onlyOwner {
        MINT_GOD_PRICE_3 = _price;
    }

    function setEthSoldPercent(uint256 _percent) external onlyOwner {
        MAX_TOKENS_ETH_SOLD = _percent;
    }

    /* Set the Trait parameters */
    function setMaxBackground(uint8 val) external onlyOwner {
        MAX_BACKGROUND = val;
    }

    function setMaxWeapon(uint8 val) external onlyOwner {
        MAX_WEAPON = val;
    }

    function setMaxBody(uint8 val) external onlyOwner {
        MAX_BODY = val;
    }

    function setMaxOutfit(uint8 val) external onlyOwner {
        MAX_OUTFIT = val;
    }

    function setMaxHead(uint8 val) external onlyOwner {
        MAX_HEAD = val;
    }

    function setMaxMouth(uint8 val) external onlyOwner {
        MAX_MOUTH = val;
    }

    function setMaxEyes(uint8 val) external onlyOwner {
        MAX_EYES = val;
    }

    function setMaxNose(uint8 val) external onlyOwner {
        MAX_NOSE = val;
    }

    function setMaxEyebrows(uint8 val) external onlyOwner {
        MAX_EYEBROWS = val;
    }

    function setMaxHair(uint8 val) external onlyOwner {
        MAX_HAIR = val;
    }

    function setMaxEyewear(uint8 val) external onlyOwner {
        MAX_EYEWEAR = val;
    }

    function setMaxFacialhair(uint8 val) external onlyOwner {
        MAX_FACIALHAIR = val;
    }

    function setMaxEars(uint8 val) external onlyOwner {
        MAX_EARS = val;
    }

    /**
     * enables owner to pause / unpause minting
     */
    function setPaused(bool _paused) external onlyOwner {
        if (_paused) _pause();
        else _unpause();
    }

    /**
     * @dev Internal function to set the base URI for all token IDs. It is
     * automatically added as a prefix to the value returned in {tokenURI},
     * or to the token ID if {tokenURI} is empty.
     */
    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    /**
     * @dev Returns the base URI set via {setBaseURI}. This will be
     * automatically added as a prefix in {tokenURI} to each token's URI, or
     * to the token ID if no specific URI is set for that token ID.
     */
    function getBaseURI() public view returns (string memory) {
        return baseURI;
    }

    /** RENDER */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        IDwarfs_NFT.DwarfTrait memory s = tokenTraits[tokenId];
        bytes memory t = new bytes(15);
        t[0] = bytes1((uint8)(s.background_weapon >> 8));
        t[1] = bytes1((uint8)(s.background_weapon & 0x00FF));

        t[2] = bytes1((uint8)(s.body_outfit >> 8));
        t[3] = bytes1((uint8)(s.body_outfit & 0x00FF));

        t[4] = bytes1((uint8)(s.head_ears >> 8));
        t[5] = bytes1((uint8)(s.head_ears & 0x00FF));

        t[6] = bytes1((uint8)(s.mouth_nose >> 8));
        t[7] = bytes1((uint8)(s.mouth_nose & 0x00FF));

        t[8] = bytes1((uint8)(s.eyes_brows >> 8));
        t[9] = bytes1((uint8)(s.eyes_brows & 0x00FF));

        t[10] = bytes1((uint8)(s.hair_facialhair >> 8));
        t[11] = bytes1((uint8)(s.hair_facialhair & 0x00FF));

        t[12] = bytes1(s.eyewear);
        t[13] = bytes1(s.cityId);
        t[14] = bytes1(s.alphaIndex);

        string memory _tokenURI = base64(t);

        // If there is no base URI, return the token URI.
        if (bytes(baseURI).length == 0) {
            return string(abi.encodePacked(_tokenURI, ".json"));
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(baseURI, _tokenURI, ".json"));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    }

    string internal constant TABLE =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

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
