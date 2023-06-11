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
};
