const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const MobsterLevelList = artifacts.require('MobsterLevelList');

module.exports = async function(deployer) {
    const instance = await deployProxy(MobsterLevelList, [], { deployer });
    console.log('Deployed: ', instance.address);
};