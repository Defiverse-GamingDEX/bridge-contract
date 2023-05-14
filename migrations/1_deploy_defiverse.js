const Web3 = require("web3");
const chalk = require("cli-color");
const ContractDeployerWithTruffle = require("@evmchain/contract-deployer/src/truffle");
const { networks } = require("../truffle-config.js");

const setup = async (contractDeployer) => {
  let oracle = await contractDeployer.loadContract("Oracle");
  await oracle.addProtectedToken("0x43831636C9cEc4C9c9A950B588Ac8Ec971588754");
}

const mint = async (contractDeployer) => {
  // let wDFV = await contractDeployer.loadContract("wDFV");
  // await wDFV.mint("0x68C297EDdd953961E81532202e48b048e459c7c3", "1000000000000000000000000")

  let MockOAS = await contractDeployer.loadContract("MockOAS");
  await MockOAS.mint("0x68C297EDdd953961E81532202e48b048e459c7c3", "1000000000000000000000000")
}

const migrate = async (contractDeployer) => {
  let VotingEscrow = await contractDeployer.loadContract("VotingEscrow");

  //await VotingEscrow.migrate("0x343eCF760a020936eEE8D655b43C5cBD40769A05");
  await VotingEscrow.migrate("0xf9209B6F49BB9fD73422BA834f4cD444aE7ceacE");
};

const test2 = async (contractDeployer) => {
  console.log("\n\n");

  let VotingEscrow = await contractDeployer.loadContract("VotingEscrow");

  rs = await VotingEscrow.epoch();
  console.log("epoch: before", rs.toString());

  rs = await VotingEscrow.point_history(0);
  console.log("point_history: before", rs);

  rs = await VotingEscrow.point_history(1);
  console.log("point_history: before", rs);
};

const test = async (contractDeployer) => {
  let rs = null;
  let MockOAS = await contractDeployer.loadContract("MockOAS");
  let wDFV = await contractDeployer.loadContract("wDFV");
  let VotingEscrow = await contractDeployer.loadContract("VotingEscrow");
  const WEEK = 7 * 86400;
  const YEAR = 365 * 86400;
  const now = Math.floor(Date.now() / 1000);
  try {
    // await wDFV.mint(
    //   "0xf9209B6F49BB9fD73422BA834f4cD444aE7ceacE",
    //   "100000000000000000000000000"
    // );
    // await MockOAS.mint(
    //   "0xf9209B6F49BB9fD73422BA834f4cD444aE7ceacE",
    //   "100000000000000000000000000"
    // );
    console.log("approve: start");
    await wDFV.approve(VotingEscrow.address, "1000000000000000000000");
    console.log("approve: end");

    console.log(`locked: start: ${now + YEAR}`);
    rs = await VotingEscrow.locked(
      "0xf9209B6F49BB9fD73422BA834f4cD444aE7ceacE"
    );
    console.log("locked: end ", rs);

    rs = await VotingEscrow.epoch();
    console.log("epoch: before", rs.toString());

    rs = await VotingEscrow.user_point_epoch(
      "0xf9209B6F49BB9fD73422BA834f4cD444aE7ceacE"
    );
    console.log("user_point_epoch: before", rs.toString());

    // rs = await VotingEscrow.point_history(0);
    // console.log("point_history0: ", rs);

    // rs = await VotingEscrow.point_history(1);
    // console.log("point_history1: ", rs);

    console.log(`create_lock: start: ${now + YEAR}`);
    rs = await VotingEscrow.create_lock("1000000000000000000", now + YEAR);
    console.log("create_lock: end ", rs);

    rs = await VotingEscrow.epoch();
    console.log("epoch: after", rs.toString());

    rs = await VotingEscrow.user_point_epoch(
      "0xf9209B6F49BB9fD73422BA834f4cD444aE7ceacE"
    );
    console.log("user_point_epoch: after", rs.toString());

    rs = await VotingEscrow.balanceOf(
      "0xf9209B6F49BB9fD73422BA834f4cD444aE7ceacE"
    );
    console.log("balanceOf: after", rs.toString());

    rs = await VotingEscrow.totalSupply();
    console.log("totalSupply: after", rs.toString());

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
      wDFV: { initArgs: ["DeFi Verse Token(Mock)", "DFV"] },
      VotingEscrow: {
        initArgs: ["veDFV(Mock)", "veDFV", "config:gpt.address"],
      },
      GaugeController: {
        initArgs: ["address:VotingEscrow", "config:authorizerAdaptor.address"],
      },
      VeBoostV2: {
        initArgs: ["address:VotingEscrow"],
      },
      Oracle: {
        initArgs: [],
      },
    },
  });

  // Grant roles
  await contractDeployer.grantRoles();

  await setup(contractDeployer);

  // await mint(contractDeployer);

  // await migrate(contractDeployer);
};
