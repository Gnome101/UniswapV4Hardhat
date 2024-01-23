require("@nomiclabs/hardhat-etherscan");
require("hardhat-deploy");
require("@nomiclabs/hardhat-ethers");
require("solidity-coverage");
require("hardhat-gas-reporter");
require("hardhat-contract-sizer");
// require("dotenv").config();

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      allowUnlimitedContractSize: true,
      chainId: 31337,
    },
  },

  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
    },
    user1: {
      default: 1,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 100,
          },
        },
      },
    ],
  },
  mocha: {
    timeout: 30000, // 500 seconds max for running tests
  },
};
