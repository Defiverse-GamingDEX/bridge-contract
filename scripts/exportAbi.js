const FileSystem = require("fs");

const CONTRACT_FOLDER = "../build/contracts";

/**
 *
 * @param {string} contract
 * @param {string} outputAbiFolder
 */
const exportAbi = function (contract, subfolder, outputAbiFolder = "./abi") {
  let artifact = require(`${CONTRACT_FOLDER}/${subfolder}/${contract}.json`);
  console.log("Contract name: ", artifact.contractName);
  let abiPath = outputAbiFolder + "/" + artifact.contractName + ".json";
  console.log("\tWriting ABI file: ", abiPath);
  FileSystem.writeFileSync(abiPath, JSON.stringify(artifact.abi, null, "  "));
};
/**
 *
 * @param {string[]} contracts
 * @param {string} outputAbiFolder
 */
const exportAbis = function (contracts, subfolder, outputAbiFolder = "./abi") {
  contracts.forEach((contract) =>
    exportAbi(contract, subfolder, outputAbiFolder)
  );
};

exportAbis(["Multicall2", "wDFV", "VotingEscrow"], ".");
