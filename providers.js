require("dotenv").config();

const HDWalletProvider = require("@truffle/hdwallet-provider");

const WALLET_TESTNET = process.env.DEPLOY_PRIVATE_KEY_TESTNET;
const WALLET_MAINNET = process.env.DEPLOY_PRIVATE_KEY_TESTNET;

const providers = {
  defiverse: {
    testnet: new HDWalletProvider(
      [WALLET_TESTNET],
      "https://rpc-testnet.defi-verse.org/",
      0,
      1,
      true,
      "m/44'/60'/0'/0/",
      17117
    ),
    mainnet: new HDWalletProvider(
      [WALLET_MAINNET],
      "https://rpc.defi-verse.org/",
      0,
      1,
      true,
      "m/44'/60'/0'/0/",
      16116
    ),
  },
  oasys: {
    mainnet: new HDWalletProvider(
      WALLET_MAINNET,
      `https://rpc.mainnet.oasys.games/`,
      0,
      1,
      true,
      "m/44'/60'/0'/0/",
      248
    ),
    testnet: new HDWalletProvider(
      WALLET_TESTNET,
      `https://rpc.testnet.oasys.games/`,
      0,
      1,
      true,
      "m/44'/60'/0'/0/",
      9372
    ),
  },
};

module.exports = providers;
