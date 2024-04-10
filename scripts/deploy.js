const hre = require("hardhat");
const { ethers } = hre;

async function main() {
  console.log("== Deploy start");

  const DFProxyAdmin_expectedAddress = "0x396c7a2bb4d98207c335236020487f7488510670";
  const Bridge_expectedAddress = "0x05ff93bfb7dd2ea8f19dd15381bb63bb06db660f";
  const BridgeProxy_expectedAddress = "0xa5c4db36bd26426c186d170bf46165a937d9cad1";

  // Initialize args
  const oas_ = "0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000";
  const l2Bridge = "0x4200000000000000000000000000000000000010";
  const feeReceiver = "0x5fF7639693807A23c56FC6aEB6cD16851246396f";
  const minSigner = 1;
  const admin = "0xefb98d7283252d4f6f913e153688C015C18Fa396";

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
    l2Bridge,
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
