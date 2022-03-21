const Dwarfs_NFT = artifacts.require("Dwarfs_NFT");
const GOD = artifacts.require("GOD");
const Clan = artifacts.require("Clan");
const Traits = artifacts.require("Traits");

const nft_price = 0.0012;
let nft_amount = 3;

contract("GameOfDwarfs", function(accounts) {
    it("Traits select", async function() {
        let traits = await Traits.deployed();

        for (let i = 0; i < 200; i++) {
            await new Promise(resolve => setTimeout(resolve, 2000));
            let res = await traits.selectTraits(i, false, 0);
            console.log(i + ": " + JSON.stringify(res));
        }
    });
});