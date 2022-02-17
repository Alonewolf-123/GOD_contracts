const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const Clan = artifacts.require('Clan');
const GOD = artifacts.require('GOD');
const Dwarfs_NFT = artifacts.require('Dwarfs_NFT');

module.exports = async function(deployer) {
    const instance = await deployProxy(Clan, [Dwarfs_NFT.address, GOD.address], { deployer });
    console.log('Deployed: ', instance.address);
};