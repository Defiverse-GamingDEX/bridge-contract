// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.18;

interface IPeggedTokenBridgeV2 {
    event Mint(
        bytes32 mintId,
        address token,
        address account,
        uint256 amount,
        // ref_chain_id defines the reference chain ID, taking values of:
        // 1. The common case: the chain ID on which the remote corresponding deposit or burn happened;
        // 2. Refund for wrong burn: this chain ID on which the burn happened
        uint64 refChainId,
        // ref_id defines a unique reference ID, taking values of:
        // 1. The common case of deposit/burn-mint: the deposit or burn ID on the remote chain;
        // 2. Refund for wrong burn: the burn ID on this chain
        bytes32 refId,
        address depositor
    );
    event Burn(
        bytes32 burnId,
        address token,
        address account,
        uint256 amount,
        uint64 toChainId,
        address toAccount,
        uint64 nonce
    );
    event MinBurnUpdated(address token, uint256 amount);
    event MaxBurnUpdated(address token, uint256 amount);
    event SupplyUpdated(address token, uint256 supply);

    /**
     * @notice Mint tokens triggered by deposit at a remote chain's OriginalTokenVault.
     * @param _request The serialized Mint protobuf.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the sigsVerifier's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function mint(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external returns (bytes32);

    /**
     * @notice Burn pegged tokens to trigger a cross-chain withdrawal of the original tokens at a remote chain's
     * OriginalTokenVault, or mint at another remote chain
     * NOTE: This function DOES NOT SUPPORT fee-on-transfer / rebasing tokens.
     * @param _token The pegged token address.
     * @param _amount The amount to burn.
     * @param _toChainId If zero, withdraw from original vault; otherwise, the remote chain to mint tokens.
     * @param _toAccount The account to receive tokens on the remote chain
     * @param _nonce A number to guarantee unique depositId. Can be timestamp in practice.
     */
    function burn(
        address _token,
        uint256 _amount,
        uint64 _toChainId,
        address _toAccount,
        uint64 _nonce
    ) external returns (bytes32);

    // same with `burn` above, use openzeppelin ERC20Burnable interface
    function burnFrom(
        address _token,
        uint256 _amount,
        uint64 _toChainId,
        address _toAccount,
        uint64 _nonce
    ) external returns (bytes32);

    function executeDelayedTransfer(bytes32 id) external;

    function minBurn(address token) external view returns (uint256);
    function maxBurn(address token) external view returns (uint256);
}
