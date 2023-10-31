const providers = require("./providers");

module.exports = {
  networks: {
    // development: {
    //   host: "127.0.0.1",
    //   port: 9545,
    //   network_id: "*",
    // },
    "token-testnet": {
      provider: providers.defiverse.testnet,
      network_id: "*",
      timeoutBlocks: 40000,
      confirmations: 0,
      skipDryRun: true,
    },
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
    "oracle-sandverse": {
      provider: providers.sandverse.testnet,
      network_id: 20197,
      timeoutBlocks: 40000,
      confirmations: 0,
      skipDryRun: true,
    },
    "bridge-oasys-mainnet": {
      provider: providers.oasys.mainnet,
      network_id: "*",
      timeoutBlocks: 40000,
      confirmations: 0,
      skipDryRun: true,
      gasPrice: 0,
    },
    "bridge-oasys-testnet": {
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
