const Dwarfs_NFT = artifacts.require("Dwarfs_NFT");
const GOD = artifacts.require("GOD");
const Traits = artifacts.require("Traits");

module.exports = function(deployer) {
    deployer.deploy(Dwarfs_NFT, GOD.address, Traits.address);
};