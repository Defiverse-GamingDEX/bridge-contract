const Web3 = require("web3");
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
      MockOAS: { initArgs: ["OAS(Mock)", "OAS"] },
      DefiverseGovernanceToken: {
        initArgs: ["Defiverse Governance Token", "DFV"],
      },
    },
  });

  // Grant roles
  await contractDeployer.grantRoles();

  await mint(contractDeployer);
};

const mint = async (contractDeployer) => {
  console.log("\n=======mint");

  // OAS
  {
    let contract = await contractDeployer.loadContract("MockOAS");

    await contract.mint(
      "0x68C297EDdd953961E81532202e48b048e459c7c3",
      "100000000000000000000000000"
    );
  }

  // DFV
  {
    let contract = await contractDeployer.loadContract(
      "DefiverseGovernanceToken"
    );

    await contract.mint(
      "0x68C297EDdd953961E81532202e48b048e459c7c3",
      "100000000000000000000000000"
    );
  }

  console.log("Done!");
};
