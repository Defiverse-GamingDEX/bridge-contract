const ethers = require("ethers");
const { JsonRpcProvider } = require("@ethersproject/providers");
const { base64, getAddress, hexlify } = require("ethers/lib/utils");
const cBridgeAbi = require("../abi/cBridge.json");

async function main() {
  const wd_onchain =
    "CAEQ14KstgYaFJ0OwuKezk3j+Gg6E4PjlmeqDue7IhTAKqo5siP+jQoOXE8n6tkIPHVswioHsaK8LsUAADIgxgAhFFU0gukkLcDRrsyItCLFddtwMUmoUpB4y9fLNjk=";
  const _signers = [];
  const sorted_sigs = [];
  const _powers = [];

  const wdmsg = base64.decode(wd_onchain);

  const signers = _signers.map((item) => {
    const decodeSigners = base64.decode(item);
    const hexlifyObj = hexlify(decodeSigners);
    return getAddress(hexlifyObj);
  });

  const sigs = sorted_sigs.map((item) => {
    return base64.decode(item);
  });

  const powers = _powers.map((item) => {
    return base64.decode(item);
  });

  console.log("wdmsg:", wdmsg);
  console.log("sigs:", sigs);
  console.log("signers:", signers);
  console.log("powers:", powers);

  const privateKey = "";
  const rpcUrl = "https://ethereum.blockpi.network/v1/rpc/public";

  const cBridgeAddr = "0x5427fefa711eff984124bfbb1ab6fbf5e3da1820";
  const provider = new JsonRpcProvider(rpcUrl);
  const signer = new ethers.Wallet(privateKey, provider);
  const contract = new ethers.Contract(cBridgeAddr, cBridgeAbi, signer);

  console.log("cBridge->withdraw ...");
  const rs = await contract.withdraw(wdmsg, sigs, signers, powers);
  console.log("\ttx:", rs.hash);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
