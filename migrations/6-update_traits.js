const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const Traits = artifacts.require('Traits');

module.exports = async function(deployer) {
    const instance = await upgradeProxy("0x1fd5bA155d9de7C48ecE085F7fA061F0870719c9", Traits, { deployer });
    console.log("Upgraded", instance.address);
};