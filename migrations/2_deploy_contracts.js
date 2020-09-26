const BentoToken = artifacts.require("./BentoToken.sol");

module.exports = function (deployer) {
  deployer.deploy(BentoToken, 271000);
};
