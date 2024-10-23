const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  console.log("== Deploy start");

  const isVerify = false;

  const DFProxyAdmin_expectedAddress = "0xC3a17A80f429693F40e756c299C4033a7EF31f42";
  const Bridge_expectedAddress = "0xDDfa498B9f01912148B2FeAfBEeA044a91B3f98a";
  const BridgeProxy_expectedAddress = "0x323D29986BCA00AEF8C2cb0f93e6F55F18eb3E67";

  // Initialize args
  const oas_ = "0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000";
  const feeReceiver = "0x5fF7639693807A23c56FC6aEB6cD16851246396f";
  const minSigner = 1;
  const admin = "0x1f15e7C7fA5bC85D228E6909e32069adEBC058e5";

  // Verify
  if (isVerify) {
    let bridgeContract = await hre.ethers.getContractAt(
      "Bridge",
      BridgeProxy_expectedAddress
    );
    let tx = await bridgeContract.getFeeReceiver();
    console.log("getFeeReceiver:", tx);

    const DEFAULT_ADMIN_ROLE = await bridgeContract.DEFAULT_ADMIN_ROLE();
    const OPERATOR_ROLE = await bridgeContract.OPERATOR_ROLE();

    tx = await bridgeContract.hasRole(OPERATOR_ROLE, admin);
    console.log("hasRole OPERATOR_ROLE:", tx);

    tx = await bridgeContract.hasRole(DEFAULT_ADMIN_ROLE, admin);
    console.log("hasRole DEFAULT_ADMIN_ROLE:", tx);

    return;
  }

  {
    // DFProxyAdmin
    const factory = await ethers.getContractFactory("DFProxyAdmin");
    const deplyTx = await factory.getDeployTransaction();
    console.log(`
DFProxyAdmin: deplyment bytecode:

${deplyTx.data}
`);
  }

  {
    // Bridge logic
    const factory = await ethers.getContractFactory("Bridge");
    const deplyTx = await factory.getDeployTransaction();
    console.log(`
Bridge: deplyment bytecode:

${deplyTx.data}
`);
  }

  {
    // BridgeProxy
    const factory = await ethers.getContractFactory("DFProxy");
    const deplyTx = await factory.getDeployTransaction(
      Bridge_expectedAddress,
      DFProxyAdmin_expectedAddress
    );
    console.log(`
DFProxy: deplyment bytecode:

${deplyTx.data}
`);
  }

  const bridgeProxy = await ethers.getContractAt(
    "Bridge",
    BridgeProxy_expectedAddress
  );
  const call = await bridgeProxy.populateTransaction.initialize(
    oas_,
    feeReceiver,
    minSigner,
    admin
  );

  console.log(`
initialize calldata:

${call.data}
`);

  console.log("== Deploy done");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
