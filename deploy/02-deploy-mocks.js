const { network } = require("hardhat");
const { verify } = require("../utils/verify");
module.exports = async function ({ getNamedAccounts, deployments }) {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();
  log("------------------------------------------------------------");

  args = [];
  const EPICDAI = await deploy("EPICDAI", {
    from: deployer,
    args: args,
    log: true,
    blockConfirmations: 2,
  });
  //   if (chainId != 31337) {
  //     log("Verifying...");
  //     await verify(EPICDAI.address, args, "contracts/Mocks/EpicDai.sol:EPICDAI");
  //   }
  const GNOME = await deploy("GNOME", {
    from: deployer,
    args: args,
    log: true,
    blockConfirmations: 2,
  });
  //   if (chainId != 31337) {
  //     log("Verifying...");
  //     await verify(HOG.address, args, "contracts/Mocks/Hog.sol:HOG");
  //   }
};
module.exports.tags = ["all", "Tokens", "Local"];
