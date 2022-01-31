const Woolf = artifacts.require("Woolf");
const WOOL = artifacts.require("WOOL");
const Traits = artifacts.require("Traits");

module.exports = function(deployer) {
    deployer.deploy(Woolf, WOOL.address, Traits.address, 50000);
};