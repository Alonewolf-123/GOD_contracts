const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const Traits = artifacts.require('Traits');
const GOD = artifacts.require('GOD');
const Dwarfs_NFT = artifacts.require('Dwarfs_NFT');

module.exports = async function(deployer) {
    const instance = await deployProxy(Dwarfs_NFT, [GOD.address, Traits.address], { deployer });
    console.log('Deployed: ', instance.address);
};