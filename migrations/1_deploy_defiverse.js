const Web3 = require("web3");
const chalk = require("cli-color");
const ContractDeployerWithTruffle = require("@evmchain/contract-deployer/src/truffle");
const { networks } = require("../truffle-config.js");

const test = async (contractDeployer) => {
  let rs = null;
  let MockOAS = await contractDeployer.loadContract("MockOAS");
  let DFV = await contractDeployer.loadContract("wDFV");
  // let veDFV = await contractDeployer.loadContract("veDFV");

  try {
    // await wDFV.mint(
    //   "0xf9209B6F49BB9fD73422BA834f4cD444aE7ceacE",
    //   "100000000000000000000000000"
    // );
    // await MockOAS.mint(
    //   "0xf9209B6F49BB9fD73422BA834f4cD444aE7ceacE",
    //   "100000000000000000000000000"
    // );
    // await wDFV.approve(GPT4veDFV.address, "100000000000000000000");
    // await GPT4veDFV.unlockGPT();
    // await GPT4veDFV.lockGPT("1000000000000000000", 365);
    // rs = await GPT4veDFV.estimateReward("1000000000000000000", 365);
    // console.log("getReward:", rs.toString());
    // rs = await GPT4veDFV.lockPeriodPerReward();
    // console.log("veDFVPerDay:", rs.toString());
    // rs = await GPT4veDFV.minLockPeriod();
    // console.log("minLockPeriod:", rs.toString());
    // rs = await GPT4veDFV.userInfo("0xf9209B6F49BB9fD73422BA834f4cD444aE7ceacE");
    // console.log("userInfo:", rs);
    // rs = await veDFV.balanceOf("0xf9209B6F49BB9fD73422BA834f4cD444aE7ceacE");
    // console.log("balanceOf:", rs.toString());
  } catch (ex) {
    console.error(ex);
  }
};

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
      Multicall2: { initArgs: [] },
      MockOAS: { initArgs: ["OAS(Mock)", "OAS"] },
      DFV: { initArgs: ["DeFi Verse Token(Mock)", "DFV"] },
      VotingEscrow: {
        initArgs: ["veDFV(Mock)", "veDFV", "config:gpt.address"],
      },
    },
  });

  // Grant roles
  await contractDeployer.grantRoles();

  await test(contractDeployer);
};
