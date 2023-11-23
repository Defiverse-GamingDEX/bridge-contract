// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.18;

interface IBridge {
    struct RelayRequest {
        address sender;
        address receiver;
        address token; // Layer 1 token
        address l2Token; // Layer 2 token, address(0) if external chain
        uint256 amount;
        uint64 srcChainId;
        uint64 dstChainId;
        bytes32 srcTransferId; // desposit tx hash
    }

    event AddSigner(address signer);

    event RevokeSigner(address signer);

    event Relay(
        bytes32 transferId,
        address receiver,
        address token,
        uint256 amountOut,
        bytes32 srcTransferId
    );

    function addSigner(address signer) external;

    function revokeSigner(address signer) external;

    function setMinSigner(uint256 min) external;

    function getMinSigner() external view returns (uint256);

    function getSignerCount() external view returns (uint256);

    function isSignerExists(address signer) external view returns (bool);

    function getSwapFeeRate(
        address token,
        uint256 chainId
    ) external view returns (uint256);

    function setSwapFeeRate(
        address token,
        uint256 chainId,
        uint256 feeRate
    ) external;

    function getBaseFee(
        address token,
        uint256 chainId
    ) external view returns (uint256);

    function setBaseFee(address token, uint256 chainId, uint256 fee) external;

    function setFeeReceiver(address addr) external;

    function getFeeReceiver() external view returns (address);

    function setVerseBridge(uint256 chainId, address bridge) external;

    function setCBridge(address cbridge) external;

    function pause() external;

    function unpause() external;

    function estimateFee(
        address token,
        uint256 dstChainId,
        uint256 amountIn
    ) external view returns (uint256 amountOut, uint256 fee);

    function relayExternalRequest(
        RelayRequest calldata relayRequest_,
        uint32 maxSlippage_,
        bytes[] calldata sigs_,
        address[] calldata signers_
    ) external;

    function relayVerseRequest(
        RelayRequest calldata relayRequest_,
        bytes[] calldata sigs_,
        address[] calldata signers_
    ) external;
}