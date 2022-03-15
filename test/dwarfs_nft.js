const Dwarfs_NFT = artifacts.require("Dwarfs_NFT");
const GOD = artifacts.require("GOD");
const Clan = artifacts.require("Clan");
const Traits = artifacts.require("Traits");

const mobster_traits_list = [
    "AwwCDgIFAgIEAwgJAQIGAA==",
    "BwECBQIFBAEUAggBAwMIAA==",
    "Cg4CDQEFBAEBAQQKAQUGAA==",
    "AQEBFQMCAgEWAQAJBQUFAA==",
    "Ag8BBwIFBQETAwABAQUFAA==",
    "Aw4BCwEEAgEUAQADBgUIAA==",
    "BgMBDAMBBAQTAgABBgQIAA==",
    "Bg4BEwEFAwESAQkCAQMHAA==",
    "BAUBDwMFBAMLBAADAwUGAA=="
];

const merchant_traits_list = [
    "Bw4CDwELAQECAQAIBAAA",
    "AwYCDgEMAwQLAwABAQAA",
    "BQ8BCgEEAwEPAwABAQAA",
    "AgcBEwMKAQEVAwIBBAAA",
    "CQ4BFAEGBAEGAgQGBgAA",
    "CAQCEgENAgQGBAAFAQAA",
    "CgUCCAMKBAELAwABBAAA",
    "AgECDQIBAQESAwIIBgAA",
    "Bg4DDAIGBAEWBAACAQAA",
    "AQYDEwMDAwEHAQACAQAA",
    "CQcCAgEKAQEMAQUIBAAA",
    "AwwCAgENAgQDAgQKAgAA",
    "BwsCBQEBAgEQAQgCAQAA",
    "Bg8CBwENAwIHBAsJAgAA",
    "Bw8CAQECAQMMBAABBwAA",
    "Ag4BCAIBBQQWBAMCBAAA",
    "Aw4CBAILAwEJAgsFAgAA",
    "CA4BFwIKAQEJAgYEBgAA",
    "AgMBEwEDAQEVBAAJAgAA",
    "BAICEAEBBQEQAQUBBgAA"
];

const nft_price = 0.0012;
let nft_amount = 3;

contract("GameOfDwarfs", function(accounts) {
    it("Dwarfs NFT Mint", async function() {
        let dwarfs_nft = await Dwarfs_NFT.deployed();
        let traits = await Traits.deployed();

        let orignal_balance = await dwarfs_nft.balanceOf(accounts[0]);

        console.log("Traits address: " + Traits.address);

        console.log("Clan address: " + Clan.address);

        await traits.setMobsterTraits(mobster_traits_list);
        await traits.setMerchantTraits(merchant_traits_list);

        await dwarfs_nft.setClan(Clan.address)
        await dwarfs_nft.mint(nft_amount, { value: nft_price * 10e18 * nft_amount });

        let current_balance = await dwarfs_nft.balanceOf(accounts[0]);
        assert.equal(
            current_balance - orignal_balance,
            nft_amount,
            nft_amount + " wasn't in the first account"
        );
    });

    it("GOD token mint", async function() {
        let mint_god_amount = 50000;
        let god = await GOD.deployed();

        await god.addController(accounts[0]);
        await god.mint(accounts[0], mint_god_amount);
        let original_balance = await god.balanceOf(accounts[0]);
        assert.equal(
            original_balance,
            mint_god_amount,
            "Invalid GOD mint"
        );
    });

    it("Invest GOD to Clan", async function() {
        let tokenId = 1;
        let invest_god_amount = 1000;
        let dwarfs_nft = await Dwarfs_NFT.deployed();
        let clan = await Clan.deployed();
        let god = await GOD.deployed();

        for (var i = 1; i <= nft_amount; i++) {
            let res = await dwarfs_nft.getTokenTraits(i);
            if (res.isMerchant == true) {
                tokenId = i;
                break;
            }
        }

        let original_balance = await god.balanceOf(accounts[0]);
        await god.addController(Clan.address);
        await clan.investGods(tokenId, invest_god_amount);
        let current_balance = await god.balanceOf(accounts[0]);

        assert.equal(
            original_balance - current_balance,
            invest_god_amount,
            invest_god_amount + " wasn't invested in the first account"
        );
    });

    it("Add merchant", async function() {
        let cityId = 1;
        let tokenIds = [1, 2, 3];
        let clan = await Clan.deployed();
        let dwarfs_nft = await Dwarfs_NFT.deployed();

        for (var i = 0; i < tokenIds.length; i++) {
            let res = await dwarfs_nft.getTokenTraits(tokenIds[i]);
            if (res.isMerchant == true && res.cityId == 0) {
                await clan.addMerchantToCity(tokenIds[i], cityId);
            }
        }
    });

    it("Normal Claim", async function() {
        let tokenIds = [1, 2, 3];
        let clan = await Clan.deployed();

        // test the normal game
        await clan.claimManyFromClan(tokenIds, false);
    });

    it("Risky Claim", async function() {
        let tokenIds = [1, 2, 3];
        let clan = await Clan.deployed();
        let god = await GOD.deployed();
        let original_balance = await god.balanceOf(accounts[0]);
        // test the risk game
        await clan.claimManyFromClan(tokenIds, true);

        let current_balance = await god.balanceOf(accounts[0]);

        assert.notEqual(
            original_balance,
            current_balance,
            "Clain owe is zero"
        );
    });
});