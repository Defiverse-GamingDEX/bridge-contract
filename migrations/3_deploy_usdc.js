var FiatTokenV2_1 = artifacts.require("FiatTokenV2_1");

module.exports = async function (deployer, network, accounts) {
  const holder = "0x68C297EDdd953961E81532202e48b048e459c7c3";
  const tokenName = "USD Coin";
  const tokenSymbol = "USDC";
  const tokenCurrency = "USD";
  const tokenDecimals = 6;
  const newMasterMinter = "0x68C297EDdd953961E81532202e48b048e459c7c3";
  const newPauser = "0x68C297EDdd953961E81532202e48b048e459c7c3";
  const newBlacklister = "0x68C297EDdd953961E81532202e48b048e459c7c3";
  const newOwner = "0x68C297EDdd953961E81532202e48b048e459c7c3";
  const lostAndFound = "0x68C297EDdd953961E81532202e48b048e459c7c3";

  await deployer.deploy(FiatTokenV2_1);
  const _fiatTokenV2_1 = await FiatTokenV2_1.deployed();
  console.log("FiatTokenV2_1:", _fiatTokenV2_1.address);

  console.log("\tinitialize");
  await _fiatTokenV2_1.initialize(
    tokenName,
    tokenSymbol,
    tokenCurrency,
    tokenDecimals,
    newMasterMinter,
    newPauser,
    newBlacklister,
    newOwner
  );

  console.log("\tinitializeV2");
  await _fiatTokenV2_1.initializeV2(tokenName);

  console.log("\tinitializeV2_1");
  await _fiatTokenV2_1.initializeV2_1(lostAndFound);

  console.log("\tconfigureMinter");
  await _fiatTokenV2_1.configureMinter(holder, "200000000000");

  console.log("\tmint");
  await _fiatTokenV2_1.mint(holder, "100000000000"); //100,000

  console.log("\tDont!");
};
