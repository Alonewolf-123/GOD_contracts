const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const Traits = artifacts.require('Traits');

module.exports = async function(deployer) {
    const instance = await deployProxy(Traits, [], { deployer });
    console.log('Deployed: ', instance.address);
};