const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const GOD = artifacts.require('GOD');

module.exports = async function(deployer) {
    const instance = await deployProxy(GOD, [], { deployer });
    console.log('Deployed: ', instance.address);
};