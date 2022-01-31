// import Web3 from "web3";

const { ethers } = require("ethers");

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


contract("Dwarfs_NFT", accounts => {
    web3.eth.getAccounts().then(web3_accounts => console.log(web3_accounts));
    console.log(Clan.address);
    Dwarfs_NFT.deployed().then(function(instance) { return instance.setClan(Clan.address) });

    it("Mint testing", () =>
        Dwarfs_NFT.deployed().then(instance => instance.mint(5, true)))
});