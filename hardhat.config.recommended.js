// This is a recommended hardhat.config.js with increased gas limits
// Copy this file to your Contracts folder and rename it to hardhat.config.js
// or modify your existing hardhat.config.js with these settings

require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    hardhat: {
      mining: {
        auto: true,
        interval: 5000
      },
      allowUnlimitedContractSize: true,
      blockGasLimit: 30000000,  // Increased from default 30M (vs default 8M)
      gas: 25000000,            // Increased from default to 25M
      timeout: 60000            // Longer timeout for large contract deployments
    },
    localhost: {
      url: "http://127.0.0.1:8545/",
      accounts: {
        mnemonic: "test test test test test test test test test test test junk",
        path: "m/44'/60'/0'/0",
        initialIndex: 0,
        count: 20
      },
      gas: 25000000,            // Increased gas for local testing
      blockGasLimit: 30000000,  // Higher block gas limit
      allowUnlimitedContractSize: true
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};
