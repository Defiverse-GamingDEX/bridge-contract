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
};
