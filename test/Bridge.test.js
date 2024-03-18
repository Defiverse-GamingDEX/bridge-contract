const { expect } = require("chai");
const { ethers } = require("hardhat");
const abi = require("ethereumjs-abi");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");

async function getSignature(privateKey, request) {
  const {
    sender,
    receiver,
    token,
    l2Token,
    amount,
    srcChainId,
    dstChainId,
    srcTransferId,
  } = request;

  const values = [
    sender,
    receiver,
    token,
    l2Token,
    amount,
    srcChainId,
    dstChainId,
    srcTransferId,
  ];
  let hash =
    "0x" +
    abi
      .soliditySHA3(
        [
          "address",
          "address",
          "address",
          "address",
          "uint256",
          "uint64",
          "uint64",
          "bytes32",
        ],
        values
      )
      .toString("hex");
  const Web3 = require("web3");
  const web3 = new Web3();
  let account = web3.eth.accounts.privateKeyToAccount(privateKey);
  let signature = account.sign(hash);

  return {
    hash,
    signature: signature.signature,
    address: account.address,
  };
}

const signer1 = {
  address: "0x46F6cFf3BA26283C6Dd413EdeCFF9cbC8344eb73",
  privateKey:
    "0x4091a36cf30fafd08e51b9fef800f5d46de2ea11c647c6f31bdab11090cb2b8d",
};

const signer2 = {
  address: "0x7c8Bf858dEa6aEE6C51884a142Dd510001445d03",
  privateKey:
    "886b9e63f9b10ffef14769260faec9f722213fe89d1786dcb7456d0d49f807eb",
};

describe("Bridge", function () {
  const minSigner = 2;
  let proxyAdmin = null;
  let oas = "0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000";
  let woas = null;
  let USDT = null;
  let cbridge = null;
  let bridge = null;

  beforeEach(async () => {
    const [deployer, operator, feeReceiver, user1, user2] =
      await ethers.getSigners();

    const _ProxyAdmin = await ethers.getContractFactory("DFProxyAdmin");
    proxyAdmin = await _ProxyAdmin.deploy();

    const _WOAS = await ethers.getContractFactory("WOAS");
    woas = await _WOAS.deploy();

    const MockERC20 = await ethers.getContractFactory("MockERC20");
    USDT = await MockERC20.deploy();
    await USDT.initialize("USDT", "USDT");

    const MockCBridge = await ethers.getContractFactory("MockCBridge");
    cbridge = await MockCBridge.deploy(woas.address);

    {
      const Bridge = await ethers.getContractFactory("Bridge");
      const DFProxy = await ethers.getContractFactory("DFProxy");
      const _logic = await Bridge.deploy();
      const _proxy = await DFProxy.deploy(_logic.address, proxyAdmin.address);
      bridge = await ethers.getContractAt("Bridge", _proxy.address);
      await bridge.initialize(
        oas,
        cbridge.address,
        feeReceiver.address,
        minSigner
      );

      await bridge.setCBridge(cbridge.address);

      const SIGNER_ROLE = await bridge.SIGNER_ROLE();
      await bridge.grantRole(SIGNER_ROLE, signer1.address);
      await bridge.grantRole(SIGNER_ROLE, signer2.address);

      const operatorRole = await bridge.OPERATOR_ROLE();
      await bridge.grantRole(operatorRole, operator.address);
    }
  });

  it("Case: Invalid signature", async function () {
    const [deployer, operator, feeReceiver, user1, user2] =
      await ethers.getSigners();

    const amount = "100000000000000000000";
    const srcChainId = 1;
    const dstChainId = 5;
    const srcTransferId =
      "0x8c79d288c3fbd456527242ff7adfab1bb295829c964a2b95a781de2944f5523d";
    const relayRequest_ = {
      sender: user1.address,
      receiver: user1.address,
      token: USDT.address,
      l2Token: USDT.address,
      amount,
      srcChainId,
      dstChainId,
      srcTransferId,
    };
    const maxSlippage_ = 10000;

    const s1 = await getSignature(signer1.privateKey, relayRequest_);
    const s2 = await getSignature(signer2.privateKey, relayRequest_);
    const sigs_ = [s1.signature, s2.signature];
    const signers_ = [signer2.address, signer1.address];

    // await USDT.connect(deployer).transfer(user1.address, amount);
    await USDT.connect(deployer).mint(user1.address, amount);
    await USDT.connect(user1).transfer(bridge.address, amount);

    expect(await USDT.balanceOf(bridge.address)).to.equal(amount);

    await expect(
      bridge
        .connect(operator)
        .relayExternalRequest(relayRequest_, maxSlippage_, sigs_, signers_)
    ).to.be.revertedWith("INVALID_SIGNATURE");
  });

  it("Case: Should bridge ERC20 token successful", async function () {
    const [deployer, operator, feeReceiver, user1, user2] =
      await ethers.getSigners();

    const amount = "100000000000000000000";
    const srcChainId = 1;
    const dstChainId = 5;
    const srcTransferId =
      "0x8c79d288c3fbd456527242ff7adfab1bb295829c964a2b95a781de2944f5523d";
    const relayRequest_ = {
      sender: user1.address,
      receiver: user1.address,
      token: USDT.address,
      l2Token: USDT.address,
      amount,
      srcChainId,
      dstChainId,
      srcTransferId,
    };
    const maxSlippage_ = 10000;

    const s1 = await getSignature(signer1.privateKey, relayRequest_);
    const s2 = await getSignature(signer2.privateKey, relayRequest_);
    const sigs_ = [s1.signature, s2.signature];
    const signers_ = [signer1.address, signer2.address];

    // await USDT.connect(deployer).transfer(user1.address, amount);
    await USDT.connect(deployer).mint(user1.address, amount);
    await USDT.connect(user1).transfer(bridge.address, amount);

    expect(await USDT.balanceOf(bridge.address)).to.equal(amount);

    await expect(
      bridge
        .connect(operator)
        .relayExternalRequest(relayRequest_, maxSlippage_, sigs_, signers_)
    )
      .to.emit(bridge, "Relay")
      .withArgs(s1.hash, user1.address, USDT.address, anyValue, srcTransferId);
  });

  it("Case: Should bridge OAS token successful", async function () {
    const [deployer, operator, feeReceiver, user1, user2] =
      await ethers.getSigners();

    const amount = "100000000000000000000";
    const srcChainId = 1;
    const dstChainId = 5;
    const srcTransferId =
      "0x8c79d288c3fbd456527242ff7adfab1bb295829c964a2b95a781de2944f5523d";
    const relayRequest_ = {
      sender: user1.address,
      receiver: user1.address,
      token: oas,
      l2Token: oas,
      amount,
      srcChainId,
      dstChainId,
      srcTransferId,
    };
    const maxSlippage_ = 10000;

    const s1 = await getSignature(signer1.privateKey, relayRequest_);
    const s2 = await getSignature(signer2.privateKey, relayRequest_);
    const sigs_ = [s1.signature, s2.signature];
    const signers_ = [signer1.address, signer2.address];

    await user1.sendTransaction({ to: bridge.address, value: amount });

    await expect(
      bridge
        .connect(operator)
        .relayExternalRequest(relayRequest_, maxSlippage_, sigs_, signers_)
    )
      .to.emit(bridge, "Relay")
      .withArgs(s1.hash, user1.address, oas, anyValue, srcTransferId);
  });
});
