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
        initArgs: [
          "config:oasys.oas",
          "config:fee-receiver.address",
          "config:min-signer",
          "config:admin.address",
        ],
      },
    },
  });

  // Grant roles
  await contractDeployer.grantRoles();

  await config(contractDeployer);

  // await testBridgeVerse(contractDeployer);

  // await test(contractDeployer);
};

const test = async (contractDeployer) => {
  let contract = await contractDeployer.loadContract("Bridge");
  let rs = null;

  rs = await contract.getFeeReceiver();
  console.log("feeReceiver:", rs);

  rs = await contract.getMinSigner();
  console.log("minSigner:", rs.toString());
};

const testBridgeVerse = async (contractDeployer) => {
  console.log("== Test bridge verse");

  let contract = await contractDeployer.loadContract("Bridge");

  const request = {
    sender: "0x68C297EDdd953961E81532202e48b048e459c7c3",
    receiver: "0x68C297EDdd953961E81532202e48b048e459c7c3",
    token: "0x683cED9B2EB62ad7b5a18e9110674F16d453c684", // L1 token - Oasys Hub
    l2Token: "0xE7798f023fC62146e8Aa1b36Da45fb70855a77Ea", // L2 token - Defiverse
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
  console.log("\n== config start ==");

  const setupCBridge = false;
  const setupVerseBridge = false;

  let contract = await contractDeployer.loadContract("Bridge");

  // grant signer
  {
    const signers = await contractDeployer.formatValue("config:signers");
    for (let i = 0; i < signers.length; i = i + 1) {
      const signer = signers[i];
      const isSignerExists = await contract.isSignerExists(signer);
      console.log(`isSignerExists: ${signer} ${isSignerExists}`);
      if (!isSignerExists) {
        const rs = await contract.addSigner(signer);
        console.log("addSigner tx:", rs.tx);
      }
    }
  }

  console.log("");
  // min signer
  {
    const newMinSigner = await contractDeployer.formatValue(
      "config:min-signer"
    );
    const currentMinSigner = await contract.getMinSigner();
    console.log("currentMinSigner:", currentMinSigner.toString());
    console.log("newMinSigner:", newMinSigner);
    if (currentMinSigner.toString() != `${newMinSigner}`) {
      const rs = await contract.setMinSigner(newMinSigner);
      console.log("setMinSigner tx:", rs.tx);
    }
  }

  // set cBridge
  if (setupCBridge) {
    console.log("");

    const newCBridge = await contractDeployer.formatValue(
      "config:cbridge.address"
    );
    console.log("setCBridge:", newCBridge);
    const rs = await contract.setCBridge(newCBridge);
    console.log("setCBridge tx:", rs.tx);
  }

  // set Verse Bridge
  if (setupVerseBridge) {
    console.log("");

    const chainIds = await contractDeployer.formatValue(
      "config:oasys.l1-bridge.id"
    );
    const bridges = await contractDeployer.formatValue(
      "config:oasys.l1-bridge.address"
    );

    for (let i = 0; i < chainIds.length; i = i + 1) {
      console.log("Set VerseBridge:", chainIds[i], bridges[i]);
      const rs = await contract.setVerseBridge(chainIds[i], bridges[i]);
      console.log("setVerseBridge tx:", rs.tx);
    }
  }

  console.log("== config done ==\n");
};
