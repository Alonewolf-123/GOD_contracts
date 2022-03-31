const { upgradeProxy } = require('@openzeppelin/truffle-upgrades');

const Clan = artifacts.require('Clan');

module.exports = async function(deployer) {
    const instance = await upgradeProxy("0xCFb14701f76089e5377a3cA7BA9e20754D32c024", Clan, { deployer });
    console.log("Upgraded", instance.address);
};