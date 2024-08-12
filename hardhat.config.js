require("dotenv").config();

require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-gas-reporter");
require("solidity-coverage");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      gasPrice: 875000000,
    },
    oasys: {
      // gasPrice: 110000000000,
      url: "https://rpc.mainnet.oasys.games",
      accounts: [process.env.DEPLOY_PRIVATE_KEY_MAINNET],
    },
    oasys_testnet: {
      // gasPrice: 110000000000,
      url: "https://rpc.testnet.oasys.games",
      accounts: [process.env.DEPLOY_PRIVATE_KEY_MAINNET],
    },
    defiverse: {
      gasPrice: 110000000000,
      url: "https://rpc.defi-verse.org/",
      accounts: [process.env.DEPLOY_PRIVATE_KEY_MAINNET],
    },
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
  },
};
