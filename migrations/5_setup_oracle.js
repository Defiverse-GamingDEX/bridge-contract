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
      Oracle: {
        initArgs: [],
      },
    },
  });

  // Grant roles
  await contractDeployer.grantRoles();

  await setupOracle(contractDeployer);
};

const setupOracle = async (contractDeployer) => {
  console.log("=======setupOracle");

  let contract = await contractDeployer.loadContract("Oracle");
  let tx = null;

  tx = await contract.setWhitelist(
    "0x009CDD611A50556fE381096524B2ac25B171A4A8",
    true
  );
  console.log("=======setWhitelist:", tx);

  // await contract.addProtectedToken(
  //   "0xBa262EF8D6411DCB3988149F2B7fAc75983F6a23"
  // );

  tx = await contract.isWhitelisted(
    "0x009CDD611A50556fE381096524B2ac25B171A4A8"
  );
  console.log("=======isWhitelisted:", tx);

  // const list = await contract.getProtectedTokens();
  // console.log("=======getProtectedTokens:", list);

  // const rs = await contract.getSellable(
  //   "0xF4B00B5127821741EFB36B4dDCAAe4841fD22423",
  //   "0xBa262EF8D6411DCB3988149F2B7fAc75983F6a23"
  // );
  // console.log("=======getProtectedTokens:", rs.toString());
};
