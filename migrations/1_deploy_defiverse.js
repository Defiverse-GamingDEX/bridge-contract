const Web3 = require("web3");
const chalk = require("cli-color");
const ContractDeployerWithTruffle = require("@evmchain/contract-deployer/src/truffle");
const { networks } = require("../truffle-config.js");

const setup = async (contractDeployer) => {
  let oracle = await contractDeployer.loadContract("Oracle");

  let tokenA = "0x43831636C9cEc4C9c9A950B588Ac8Ec971588754";
  let tokenB = "0xCC90040a931a8147cc2A4411c68348a5a3a363a0";
  // await oracle.addProtectedToken(tokenA);
  // await oracle.addProtectedToken(tokenB);

  console.log("\nsetup");
  console.log("updateEarn");

  // await oracle.updateEarn(
  //   "0x36FB86bF34B73cF9B1ebe034DA10D9143Dc46cd6",
  //   tokenA,
  //   "10000000000000000000"
  // );
  // await oracle.updateEarn(
  //   "0x36FB86bF34B73cF9B1ebe034DA10D9143Dc46cd6",
  //   tokenB,
  //   "20000000000000000000"
  // );

  // await oracle.updateEarn(
  //   "0xfF510480dDEa89B8b50DB0B81E1C242a3F225E90",
  //   tokenA,
  //   "30000000000000000000"
  // );
  // await oracle.updateEarn(
  //   "0xfF510480dDEa89B8b50DB0B81E1C242a3F225E90",
  //   tokenB,
  //   "40000000000000000000"
  // );

  // await oracle.updateEarn(
  //   "0xC3Cb00e9B223fEa64801943d7379b86DA2C94cF0",
  //   tokenA,
  //   "500000000000000000000"
  // );
  // await oracle.updateEarn(
  //   "0xC3Cb00e9B223fEa64801943d7379b86DA2C94cF0",
  //   tokenB,
  //   "500000000000000000000"
  // );
};

const setupGauge = async (contractDeployer) => {
  let AuthorizerAdaptor = await contractDeployer.loadContract(
    "AuthorizerAdaptor"
  );

  console.log("\n");
  console.log("======================= setupGauge");

  const gaugeController = "0x782896795C815d833D1d25C9cAf418AeE57Aa011";

  let tx = await AuthorizerAdaptor.setup(
    gaugeController,
    "0x68C297EDdd953961E81532202e48b048e459c7c3"
  );
  console.log("tx:", tx);

  tx = await AuthorizerAdaptor.getGauges();
  console.log("getGauges:", tx);
};

const mint = async (contractDeployer) => {
  // let wDFV = await contractDeployer.loadContract("BalancerGovernanceToken");
  // await wDFV.mint("0x68C297EDdd953961E81532202e48b048e459c7c3", "1000000000000000000000000")

  // let MockOAS = await contractDeployer.loadContract("MockOAS");
  // await MockOAS.mint("0x68C297EDdd953961E81532202e48b048e459c7c3", "1000000000000000000000000")

  let wDFV = await contractDeployer.loadContract("BalancerGovernanceToken");
  await wDFV.mint(
    "0x68C297EDdd953961E81532202e48b048e459c7c3",
    "1000000000000000000000000"
  );
};

const test = async (contractDeployer) => {
  let wDFV = await contractDeployer.loadContract("BalancerGovernanceToken");

  let adminRole = await wDFV.DEFAULT_ADMIN_ROLE();

  await wDFV.grantRole(adminRole, "0x68C297EDdd953961E81532202e48b048e459c7c3");

  let rs = await wDFV.hasRole(
    adminRole,
    "0x68C297EDdd953961E81532202e48b048e459c7c3"
  );
  console.log("rs1:", rs);

  // let role = await wDFV.MINTER_ROLE();
  // rs = await wDFV.hasRole(role, "0x99DbC45D25698765Ca869CeCec5E25729B224B21");
  // console.log("rs2:", rs);
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
      Authorizer: {
        initArgs: ["config:admin.address"],
      },
      AuthorizerAdaptor: {
        initArgs: ["config:vault.address"],
      },
      BalancerGovernanceToken: {
        initArgs: ["DeFi Verse Governance Token", "DFV"],
      },
      Oracle: {
        initArgs: [],
      },
    },
  });

  // Grant roles
  await contractDeployer.grantRoles();

  // await mint(contractDeployer);

  // await test(contractDeployer);

  // await setupGauge(contractDeployer);

  // await setup(contractDeployer);
};
