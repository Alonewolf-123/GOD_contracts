const Clan = artifacts.require("Clan");
const Dwarfs_NFT = artifacts.require("Dwarfs_NFT");
const GOD = artifacts.require("GOD");

module.exports = function(deployer) {
    deployer.deploy(Clan, Dwarfs_NFT.address, GOD.address);
};