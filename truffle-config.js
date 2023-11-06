const providers = require("./providers");

module.exports = {
  networks: {
    "defiverse-testnet": {
      provider: providers.defiverse.testnet,
      network_id: "*",
      timeoutBlocks: 40000,
      confirmations: 0,
      skipDryRun: true,
      gasPrice: 60000000000,
    },
    "defiverse-mainnet": {
      provider: providers.defiverse.mainnet,
      network_id: "*",
      timeoutBlocks: 40000,
      confirmations: 0,
      skipDryRun: true,
      gasPrice: 5000000000000,
    },
    "oasys-mainnet": {
      provider: providers.oasys.mainnet,
      network_id: "*",
      timeoutBlocks: 40000,
      confirmations: 0,
      skipDryRun: true,
      gasPrice: 0,
    },
    "oasys-testnet": {
      provider: providers.oasys.testnet,
      network_id: "*",
      timeoutBlocks: 40000,
      confirmations: 0,
      skipDryRun: true,
      gasPrice: 0,
    },
  },

  mocha: {
    timeout: 100000,
  },

  compilers: {
    solc: {
      version: "0.8.12",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
  },

  db: {
    enabled: false,
  },
};
