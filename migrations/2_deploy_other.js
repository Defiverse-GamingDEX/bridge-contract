module.exports = async function (deployer) {
  // const multicall = artifacts.require("Multicall");
  // deployer.deploy(multicall);

  // const EventEmitter = artifacts.require("EventEmitter");
  // await deployer.deploy(EventEmitter);

  // const TokenDFV = artifacts.require("TokenDFV");
  // deployer.deploy(TokenDFV, "Defi Verse Token", "DFV", "10000000000000000000000");

  // const contract = await TokenDFV.at("0xb7e40D63d0Aee3d6ce83070DD411D901F5E44a9C");
  // await contract.mint(
  //   "0x343eCF760a020936eEE8D655b43C5cBD40769A05",
  //   "100000000000000000000000"
  // );

  const MockERC20 = await artifacts.require("MockERC20");

  // console.log('=========Deploy:aGEM');
  // await deployer.deploy(MockERC20, "aGEM", "aGEM");

  // console.log('=========Deploy:bGEM');
  // await deployer.deploy(MockERC20, "bGEM", "bGEM");

  // console.log('=========Deploy:cGEM');
  // await deployer.deploy(MockERC20, "cGEM", "cGEM");

  // console.log('=========Deploy:dGEM');
  // await deployer.deploy(MockERC20, "dGEM", "dGEM");

  // console.log('=========Deploy:eGEM');
  // await deployer.deploy(MockERC20, "eGEM", "eGEM");

  // console.log('=========Deploy:fGEM');
  // await deployer.deploy(MockERC20, "fGEM", "fGEM");

  // console.log('=========Deploy:gGEM');
  // await deployer.deploy(MockERC20, "gGEM", "gGEM");

  // console.log('=========Deploy:hGEM');
  // await deployer.deploy(MockERC20, "hGEM", "hGEM");

  const tokens = [
    "0x90D8673A62a663C7c39170f64f26B903aFFcBaFF",
    "0x72BAb75Be4f5252D0a6e9E3E9aC86210A346D10f",
    "0xdc3D8ff59A01957d1228988C64859D4a5C2ad4e2",
    "0x70c7aa9F37C8A4d3890fB10171ea34FFb3573293",
    "0x6f4ed22ECD49aAAF3Cfb73Fb5361fd5a1440c9a5",
    "0xaBD241744d87236ccaD73A3eec128D30c0c8855d",
    "0x872BA06f6F9878D31488680E937A910925Ac729D",
    "0x7aD0039B55B48a70049A0320fD0fc4A3e496e944",
  ];

  for (let i = 0; i < tokens.length; i = i + 1) {
    console.log('=========Mint:', tokens[i]);
    const contract = await MockERC20.at(tokens[i]);
    await contract.mint(
      "0x68C297EDdd953961E81532202e48b048e459c7c3",
      "10000000000000000000000000000"
    );
  }

  // const DAI = await MockERC20.at("0x8d1436958Bcbd5dB471F95e665Ac98DDE1E816f1");
  // await DAI.mint(
  //   "0x343eCF760a020936eEE8D655b43C5cBD40769A05",
  //   "100000000000000000000000"
  // );

  // const usdc = await MockERC20.at("0x01aC28D93706f5c394B853BBa1456F54d9298C8d");
  // await usdc.mint(
  //   "0x343eCF760a020936eEE8D655b43C5cBD40769A05",
  //   "100000000000000000000000"
  // );

  // const USDT = await MockERC20.at("0x4D20BFe67C3F2B3d839B25F2B0Cc942BC84C481E");
  // await USDT.mint(
  //   "0x343eCF760a020936eEE8D655b43C5cBD40769A05",
  //   "100000000000000000000000"
  // );

  // await deployer.deploy(MockERC20, "Game Token B", "GMB", "1000000000000000000000");

  // await  deployer.deploy(MockERC20, "Game Token A", "GMA", "1000000000000000000000");

  // await deployer.deploy(MockERC20, "USDT", "USDT", "10000000000000000000000");

  // const contract = await MockERC20.at("0xbDfd38435Cf396083CfBf913a8A49284DE70BF6b");
  // await contract.mint(
  //   "0x68C297EDdd953961E81532202e48b048e459c7c3",
  //   "10000000000000000000000000"
  // );

  // const contract2 = await MockERC20.at("0x167F2A85D015C6C7a06CA65230FFaf22d1dceA9f");
  // await contract2.mint(
  //   "0x68C297EDdd953961E81532202e48b048e459c7c3",
  //   "10000000000000000000000000"
  // );
};
