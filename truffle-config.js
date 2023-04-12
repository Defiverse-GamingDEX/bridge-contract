require("dotenv").config();

const HDWalletProvider = require("@truffle/hdwallet-provider");

const WALLET_TESTNET = process.env.DEPLOY_PRIVATE_KEY_TESTNET;
const WALLET_MAINNET = process.env.DEPLOY_PRIVATE_KEY_MAINNET;

const providerDefiVerseDev = new HDWalletProvider(
  WALLET_TESTNET,
  "https://rpc.defiverse.net/",
  0,
  1,
  true,
  "m/44'/60'/0'/0/",
  16116
);

const providerMCHVerseDev = new HDWalletProvider(
  WALLET_TESTNET,
  "https://rpc.oasys.mycryptoheroes.net/",
  0,
  1,
  true,
  "m/44'/60'/0'/0/",
  29548
);

const providerGoerli = new HDWalletProvider(
  WALLET_TESTNET,
  `https://goerli.infura.io/v3/0d5c5422f2f8442cadf23d2f3e3db385`,
  0,
  1,
  true,
  "m/44'/60'/0'/0/",
  5
);

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 9545,
      network_id: "*",
    },
    "mchverse-testnet": {
      provider: providerMCHVerseDev,
      network_id: "*",
      timeoutBlocks: 40000,
      gasPrice: 0,
    },
    "goerli-testnet": {
      provider: providerGoerli,
      network_id: "*",
      timeoutBlocks: 40000,
      confirmations: 1,
      skipDryRun: true,
    },
    "defiverse-testnet": {
      provider: providerDefiVerseDev,
      network_id: "*",
      timeoutBlocks: 40000,
      confirmations: 0,
      skipDryRun: true,
    },
  },

  mocha: {
    timeout: 100000,
  },

  compilers: {
    solc: {
      version: "0.8.10",
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
