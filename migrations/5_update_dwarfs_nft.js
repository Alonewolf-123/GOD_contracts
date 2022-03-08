const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const Dwarfs_NFT = artifacts.require('Dwarfs_NFT');

module.exports = async function(deployer) {
    const instance = await upgradeProxy("0xEC79F308585FDc8b27A9Bb77B1F586d82c2a887b", Dwarfs_NFT, { deployer });
    console.log("Upgraded", instance.address);
};