const Barn = artifacts.require("Barn");

module.exports = function(deployer) {
    deployer.deploy(Barn, "0x6Db0569afd06431AC9Ff044377907e6d2451a4cE", "0xe421ada030610f173F9db7752707C1A68Cf02832");
};