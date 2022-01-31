const Barn = artifacts.require("Barn");
const Woolf = artifacts.require("Woolf");
const WOOL = artifacts.require("WOOL");

module.exports = function(deployer) {
    deployer.deploy(Barn, Woolf.address, WOOL.address);
};