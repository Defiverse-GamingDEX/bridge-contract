require("dotenv").config();

const HDWalletProvider = require("@truffle/hdwallet-provider");

const WALLET_TESTNET = process.env.DEPLOY_PRIVATE_KEY_TESTNET;
const WALLET_MAINNET = process.env.DEPLOY_PRIVATE_KEY_TESTNET;

// const providerDefiVerseMainnet = new HDWalletProvider(
//   [WALLET_MAINNET],
//   "https://rpc.defiverse.net",
//   0,
//   1,
//   true,
//   "m/44'/60'/0'/0/",
//   16116
// );

const providerDefiVerseDev = new HDWalletProvider(
  [WALLET_TESTNET],
  "https://rpc-testnet.defiverse.net",
  0,
  1,
  true,
  "m/44'/60'/0'/0/",
  17117
);

// const providerSandVerse = new HDWalletProvider(
//   WALLET_TESTNET,
//   "https://rpc.sandverse.oasys.games/",
//   0,
//   1,
//   true,
//   "m/44'/60'/0'/0/",
//   20197
// );

module.exports = {
  networks: {
    // development: {
    //   host: "127.0.0.1",
    //   port: 9545,
    //   network_id: "*",
    // },
    // "token-testnet": {
    //   provider: providerDefiVerseDev,
    //   network_id: "*",
    //   timeoutBlocks: 40000,
    //   confirmations: 0,
    //   skipDryRun: true,
    // },
    "defiverse-testnet": {
      provider: providerDefiVerseDev,
      network_id: "*",
      timeoutBlocks: 40000,
      confirmations: 0,
      skipDryRun: true,
      gas: 0,
    },
    // "defiverse-mainnet": {
    //   provider: providerDefiVerseMainnet,
    //   network_id: "*",
    //   timeoutBlocks: 40000,
    //   confirmations: 0,
    //   skipDryRun: true,
    //   gas: 20000000,
    //   gasPrice: 2000000000000,
    // },
    // // "oracle-sandverse": {
    //   provider: providerSandVerse,
    //   network_id: 20197,
    //   timeoutBlocks: 40000,
    //   confirmations: 0,
    //   skipDryRun: true,
    // },
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
