const { deployProxy } = require('@openzeppelin/truffle-upgrades');

const Traits = artifacts.require('Traits');
const MobsterLevelList = artifacts.require('MobsterLevelList');

module.exports = async function(deployer) {
    const instance = await deployProxy(Traits, [MobsterLevelList.address], { deployer });
    console.log('Deployed: ', instance.address);
};