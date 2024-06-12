const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  console.log("== Deploy start");

  const DFProxyAdmin_expectedAddress =
    "0x48D9D629aC7Ba6c8b6c097A126c7E80c9E33fdD3";
  const Bridge_expectedAddress = "0xa67d27c4253DF50ff152166Fc8257b1e40b226c2";
  const BridgeProxy_expectedAddress =
    "0xBAC3dcc1519e06c5E92112F0462719E32Cc03C75";

  // Initialize args
  const oas_ = "0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000";
  const feeReceiver = "0x5fF7639693807A23c56FC6aEB6cD16851246396f";
  const minSigner = 1;
  const admin = "0x1f15e7C7fA5bC85D228E6909e32069adEBC058e5";

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

  // let rs = await bridgeProxy.getMinSigner();
  // console.log("== getMinSigner:", rs);

  // const adminRole = await bridgeProxy.DEFAULT_ADMIN_ROLE();
  // // const adminRole = await bridgeProxy.DEFAULT_ADMIN_ROLE();

  // const hasRole = await bridgeProxy.hasRole(adminRole, "0x68C297EDdd953961E81532202e48b048e459c7c3");
  // console.log("== hasRole:", hasRole);

  // const getRoleMember = await bridgeProxy.getRoleMember(adminRole, 0);
  // console.log("== getRoleMember:", getRoleMember);

  console.log("== Deploy done");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
