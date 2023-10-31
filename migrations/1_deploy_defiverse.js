const Web3 = require("web3");
const chalk = require("cli-color");
const ContractDeployerWithTruffle = require("@evmchain/contract-deployer/src/truffle");
const { networks } = require("../truffle-config.js");

const performFirstStage = async (contractDeployer) => {
  console.log("\n");
  console.log("======================= performFirstStage");

  let AuthorizerAdaptor = await contractDeployer.loadContract(
    "AuthorizerAdaptor"
  );

  let tx = await AuthorizerAdaptor.performFirstStage();
  console.log("tx:", tx);

  tx = await AuthorizerAdaptor.getGauges();
  console.log("getGauges:", tx);

  console.log("======================= Done!\n");
};

const performSecondStage = async (contractDeployer) => {
  console.log("\n");
  console.log("======================= performSecondStage");

  let AuthorizerAdaptor = await contractDeployer.loadContract(
    "AuthorizerAdaptor"
  );

  let tx = await AuthorizerAdaptor.performSecondStage();
  console.log("tx:", tx);

  tx = await AuthorizerAdaptor.getGauges();
  console.log("getGauges:", tx);

  console.log("======================= Done!\n");
};

const performThirdStage = async (contractDeployer) => {
  console.log("\n");
  console.log("======================= performThirdStage");

  // let AuthorizerAdaptor = await contractDeployer.loadContract(
  //   "AuthorizerAdaptor"
  // );

  // let tx = await AuthorizerAdaptor.performSecondStage();
  // console.log("tx:", tx);

  // tx = await AuthorizerAdaptor.getGauges();
  // console.log("getGauges:", tx);

  console.log("======================= Done!\n");
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

const setupReward = async (contractDeployer) => {
  let AuthorizerAdaptor = await contractDeployer.loadContract(
    "AuthorizerAdaptor"
  );

  let tx = await AuthorizerAdaptor.setupReward();
  console.log("tx:", tx);
};

const setupGaugeTypeWeight = async (contractDeployer) => {
  let AuthorizerAdaptor = await contractDeployer.loadContract(
    "AuthorizerAdaptor"
  );

  let tx = await AuthorizerAdaptor.setupGaugeTypeWeight(
    "0x782896795C815d833D1d25C9cAf418AeE57Aa011"
  );
  console.log("tx:", tx);
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
      DefiverseGovernanceToken: {
        initArgs: ["Defiverse Governance Token", "DFV"],
      },
      // BalancerGovernanceToken: {
      //   initArgs: ["Defiverse Governance Token", "DFV"],
      // },
      Authorizer: {
        initArgs: ["config:admin.address"],
      },
      AuthorizerAdaptor: {
        initArgs: ["config:vault.address"],
      },
      WOAS: { initArgs: [] },
      Oracle: {
        initArgs: [],
      },
    },
  });

  // Grant roles
  await contractDeployer.grantRoles();

  // await setupReward(contractDeployer);

  // await setupGaugeTypeWeight(contractDeployer);

  // await setupOracle(contractDeployer);
  // await whitelistOracle(contractDeployer);
  
  // await setupVault(contractDeployer);

  // await setupRole(contractDeployer);
  // await performFirstStage(contractDeployer);
  // await performSecondStage(contractDeployer);
  // await performThirdStage(contractDeployer);
};

const setupRole = async (contractDeployer) => {
  console.log("\n=======setupRole");

  let contract = await contractDeployer.loadContract(
    "DefiverseGovernanceToken"
  );
  const rs = await contract.grantRole(
    await contract.DEFAULT_ADMIN_ROLE(),
    "0x4446474b9cb112158244D880A55bcCf049EbA1Ba"
  );

  console.log("\n=======setupRole:", rs);
};

const setupVault = async (contractDeployer) => {
  console.log("\n=======setupVault");

  let contract = await contractDeployer.loadContract("AuthorizerAdaptor");
  const rs = await contract.setVault(
    "0x3fb170D197FFA0e79F758d0730efaC41807E4852"
  );

  console.log("\n=======setupVault:", rs);
};

const whitelistOracle = async (contractDeployer) => {
  console.log("\n=======whitelistOracle");
  let tx = null;

  let contract = await contractDeployer.loadContract("Oracle");
  tx = await contract.setWhitelist(
    "0xFdbDeb40F8E733a2453b68Eb911A2Ad48caC91a3",
    true
  );
  console.log("==setWhitelist:", tx);
};

const setupOracle = async (contractDeployer) => {
  console.log("\n=======setupOracle");
  let tx = null;

  let contract = await contractDeployer.loadContract("Oracle");

  const wallets = [
    // "0x5E07339ef374E362E597AED56786F9D3FfA44C99",
    // "0xF68Ab2a33D0F94983BCb4d3aA978361a6Ca9a028",
    // "0xA9670dC72Edc9f4FB01f4DC0ba7F85CC62a152ff",
    // "0x02B924E4A404A724DC5Bf793188932049AEE6624",
    "0x68C297EDdd953961E81532202e48b048e459c7c3",
  ];

  const GMA = "0x43831636C9cEc4C9c9A950B588Ac8Ec971588754";
  const GMB = "0xCC90040a931a8147cc2A4411c68348a5a3a363a0";

  for (let i = 0; i < wallets.length; i = i + 1) {
    console.log("==updateEarn1:", wallets[i]);
    const tx = await contract.updateEarn(
      wallets[i],
      GMA,
      "1000000000000000000000"
    );
    console.log("==updateEarn1:", tx);
  }

  for (let i = 0; i < wallets.length; i = i + 1) {
    const tx = await contract.updateEarn(
      wallets[i],
      GMB,
      "1000000000000000000000"
    );
    console.log("==updateEarn2:", tx);
  }

  // tx = await contract.getSellable(wallets[0], GMB);
  // console.log("getSellable GMB:", tx);

  let user = "0x68C297EDdd953961E81532202e48b048e459c7c3";
  const token = "0x43831636C9cEc4C9c9A950B588Ac8Ec971588754";

  // tx = await contract.isProtectedToken(token);
  // console.log(`isProtectedToken:`, tx.toString());

  tx = await contract.getSellable(user, token);
  console.log(`getSellable GMA of ${user} is:`, tx.toString());

  // user = "0x68C297EDdd953961E81532202e48b048e459c7c3";
  // tx = await contract.getSellable(user, token);
  // console.log(`getSellable GMA of ${user} is:`, tx.toString());
};
