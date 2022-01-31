const Woolf = artifacts.require("Woolf");

module.exports = function(deployer) {
    deployer.deploy(Woolf, "0xe421ada030610f173F9db7752707C1A68Cf02832", "0xC9bEd6BF694c25E29cEEa1A16E044e6302723f4f", 50000);
};