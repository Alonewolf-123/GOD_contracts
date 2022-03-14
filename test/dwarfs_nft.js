const Dwarfs_NFT = artifacts.require("Dwarfs_NFT");
const God = artifacts.require("God");
const Clan = artifacts.require("Clan");
const Traits = artifacts.require("Traits");

const traits_list = ["AwwCDgIFAgIEAwgJAQIGAA==",
    "BwECBQIFBAEUAggBAwMIAA==",
    "Cg4CDQEFBAEBAQQKAQUGAA==",
    "AQEBFQMCAgEWAQAJBQUFAA==",
    "Ag8BBwIFBQETAwABAQUFAA==",
    "Aw4BCwEEAgEUAQADBgUIAA==",
    "BgMBDAMBBAQTAgABBgQIAA==",
    "Bg4BEwEFAwESAQkCAQMHAA==",
    "BAUBDwMFBAMLBAADAwUGAA=="
];
const nft_price = 0.0012;

contract("Dwarfs_NFT", function(accounts) {
    it("Mint", async function() {
        let amount = 3;
        let dwarfs_nft = await Dwarfs_NFT.deployed();
        let traits = await Traits.deployed();

        let orignal_balance = await dwarfs_nft.balanceOf(accounts[0]);

        console.log("Traits address: " + Traits.address);

        console.log("Clan address: " + Clan.address);

        await traits.setNFTTraits(traits_list);
        await dwarfs_nft.setClan(Clan.address)
        await dwarfs_nft.mint(amount, { value: nft_price * 10e18 * amount });

        let current_balance = await dwarfs_nft.balanceOf(accounts[0]);
        assert.equal(
            current_balance - orignal_balance,
            amount,
            amount + " wasn't in the first account"
        );
    });

    it("Invest", async function() {
        let tokenId = 1;
        let amount = 10000;
        let clan = Clan.deployed();
        let god = God.deployed();
        let original_balance = await god.balanceOf(accounts[0]);
        await clan.investGods(tokenId, amount);
        let current_balance = await god.balanceOf(accounts[0]);

        assert.equal(
            original_balance - current_balance,
            amount,
            amount + " wasn't invested in the first account"
        );
    });

    it("Add merchant", async function() {
        let cityId = 1;
        let tokenIds = [1, 2, 3];
        let clan = Clan.deployed();

        for (var i = 0; i < tokenIds.length; i++) {
            await clan.addMerchantToCity(tokenIds[i], cityId);
        }
    });

    it("Normal Claim", async function() {
        let tokenIds = [1, 2, 3];
        let clan = Clan.deployed();

        // test the normal game
        await clan.claimManyFromClan(tokenIds, false);
    });

    it("Risky Claim", async function() {
        let tokenIds = [1, 2, 3];
        let clan = Clan.deployed();
        let god = God.deployed();
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