// import Web3 from "web3";

const { ethers } = require("ethers");
const _deploy_traits = require("../migrations/1_deploy_traits");

const Dwarfs_NFT = artifacts.require("Dwarfs_NFT");
const Clan = artifacts.require("Clan");
// Is there is an injected web3 instance?
// var web3Provider;

// if (typeof web3 !== 'undefined') {
//     web3Provider = web3.currentProvider;
//     web3 = new Web3(web3.currentProvider);
// } else {
//     // If no injected web3 instance is detected, fallback to Truffle Develop.
//     web3Provider = new web3.providers.HttpProvider('http://127.0.0.1:7545');
//     web3 = new Web3(App.web3Provider);
// }

contract("Dwarfs_NFT", function(accounts) {
    it("Clan test"), async function() {
        let clan = await Clan.deployed();
        let cityId = clan.getAvailableCity();
        console.log(cityId);
        console.log(clan.getNumMobstersOfCity(cityId));
    })

it("Mint testing", async function() {
    let dwarfs_nft = await Dwarfs_NFT.deployed();
    dwarfs_nft.setClan(Clan.address)

    // let amount = 2;
    // dwarfs_nft.mint(amount, { value: 0.0012 * 10e18 * amount });
    dwarfs_nft.mint(2, { value: 0.0012 * 10e18 * 2 });

})
});