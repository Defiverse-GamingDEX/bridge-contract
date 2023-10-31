const Web3 = require("web3");
const chalk = require("cli-color");
const ContractDeployerWithTruffle = require("@evmchain/contract-deployer/src/truffle");
const { networks } = require("../truffle-config.js");

module.exports = async function (deployer, network, accounts) {
  const { provider } = networks[network] || {};
  if (!provider) {
    throw new Error(`Unable to find provider for network: ${network}`);
  }

  const web3 = new Web3(provider);
  const deployConfig = {
    dataFilename: `./networks/${network}.json`,
    deployData: require(`../networks/${network}.json`),
    proxyAdminName: "DFProxyAdmin",
    proxyName: "DFProxy",
  };

  const contractDeployer = new ContractDeployerWithTruffle({
    artifacts,
    deployer,
  });
  contractDeployer.setWeb3(web3);
  contractDeployer.setConfig(deployConfig);

  // Initialize
  await contractDeployer.init();

  // Deploy contract
  await contractDeployer.deployAllManifests({
    args: {
      Bridge: {
        initArgs: ["config:oasys.oas", "config:oasys.l2-bridge.address"],
      },
    },
  });

  // Grant roles
  await contractDeployer.grantRoles();

  // await config(contractDeployer);

  // await testBridgeVerse(contractDeployer);
};

const testBridgeVerse = async (contractDeployer) => {
  console.log("== Test bridge verse");

  let contract = await contractDeployer.loadContract("Bridge");

  const request = {
    sender: "0x68C297EDdd953961E81532202e48b048e459c7c3",
    receiver: "0x68C297EDdd953961E81532202e48b048e459c7c3",
    srcToken: "0x580eBb24958c7211099F185ac3558c2587EFdc6F", // L2 token - Sandverse
    dstToken: "0xE7798f023fC62146e8Aa1b36Da45fb70855a77Ea", // L2 token - Defiverse
    hubToken: "0x683cED9B2EB62ad7b5a18e9110674F16d453c684", // L1 token - Oasys Hub
    amount: "15000000000000000000", // 15
    srcChainId: 20197, // sandverse
    dstChainId: 17117, // defiverse
    srcTransferId:
      "0xa5b9d60f32436310afebcfda832817a68921beb782fabf7915cc0460b4431169",
  };
  const sigs = [];
  const signers = [];
  const rs = await contract.relayVerseRequest(request, sigs, signers);
  console.log("== done tx:", rs.tx);
};

const config = async (contractDeployer) => {
  console.log("== config");

  let contract = await contractDeployer.loadContract("Bridge");
  const chainIds = await contractDeployer.formatValue(
    "config:oasys.l1-bridge.id"
  );
  const bridges = await contractDeployer.formatValue(
    "config:oasys.l1-bridge.address"
  );

  for (let i = 0; i < chainIds.length; i = i + 1) {
    console.log("Set VerseBridge:", chainIds[i], bridges[i]);
    await contract.setVerseBridge(chainIds[i], bridges[i]);
  }

  const cbridge = contractDeployer.formatValue("config:cbridge.address");
  console.log("Set CBridge:", cbridge);
  await contract.setCBridge(cbridge);
};
