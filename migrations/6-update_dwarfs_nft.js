const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const Dwarfs_NFT = artifacts.require('Dwarfs_NFT');

module.exports = async function(deployer) {
    // 0x2620bB91919B90060c376e15e72521EFEdA7d627 rinkeby
    const instance = await upgradeProxy("0x8592005c5BE50cD07a1F3D10AFa8c3A06F090213", Dwarfs_NFT, { deployer });
    console.log("Upgraded", instance.address);
};