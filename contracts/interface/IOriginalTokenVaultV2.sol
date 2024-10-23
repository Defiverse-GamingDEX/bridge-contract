// SPDX-License-Identifier: GPL-3.0-only

pragma solidity ^0.8.18;

interface IOriginalTokenVaultV2 {
    event Deposited(
        bytes32 depositId,
        address depositor,
        address token,
        uint256 amount,
        uint64 mintChainId,
        address mintAccount,
        uint64 nonce
    );
    event Withdrawn(
        bytes32 withdrawId,
        address receiver,
        address token,
        uint256 amount,
        // ref_chain_id defines the reference chain ID, taking values of:
        // 1. The common case of burn-withdraw: the chain ID on which the corresponding burn happened;
        // 2. Pegbridge fee claim: zero / not applicable;
        // 3. Refund for wrong deposit: this chain ID on which the deposit happened
        uint64 refChainId,
        // ref_id defines a unique reference ID, taking values of:
        // 1. The common case of burn-withdraw: the burn ID on the remote chain;
        // 2. Pegbridge fee claim: a per-account nonce;
        // 3. Refund for wrong deposit: the deposit ID on this chain
        bytes32 refId,
        address burnAccount
    );
    event MinDepositUpdated(address token, uint256 amount);
    event MaxDepositUpdated(address token, uint256 amount);

    /**
     * @notice Lock original tokens to trigger cross-chain mint of pegged tokens at a remote chain's PeggedTokenBridge.
     * NOTE: This function DOES NOT SUPPORT fee-on-transfer / rebasing tokens.
     * @param _token The original token address.
     * @param _amount The amount to deposit.
     * @param _mintChainId The destination chain ID to mint tokens.
     * @param _mintAccount The destination account to receive the minted pegged tokens.
     * @param _nonce A number input to guarantee unique depositId. Can be timestamp in practice.
     */
    function deposit(
        address _token,
        uint256 _amount,
        uint64 _mintChainId,
        address _mintAccount,
        uint64 _nonce
    ) external returns (bytes32);

    /**
     * @notice Lock native token as original token to trigger cross-chain mint of pegged tokens at a remote chain's
     * PeggedTokenBridge.
     * @param _amount The amount to deposit.
     * @param _mintChainId The destination chain ID to mint tokens.
     * @param _mintAccount The destination account to receive the minted pegged tokens.
     * @param _nonce A number input to guarantee unique depositId. Can be timestamp in practice.
     */
    function depositNative(
        uint256 _amount,
        uint64 _mintChainId,
        address _mintAccount,
        uint64 _nonce
    ) external payable returns (bytes32);

    /**
     * @notice Withdraw locked original tokens triggered by a burn at a remote chain's PeggedTokenBridge.
     * @param _request The serialized Withdraw protobuf.
     * @param _sigs The list of signatures sorted by signing addresses in ascending order. A relay must be signed-off by
     * +2/3 of the bridge's current signing power to be delivered.
     * @param _signers The sorted list of signers.
     * @param _powers The signing powers of the signers.
     */
    function withdraw(
        bytes calldata _request,
        bytes[] calldata _sigs,
        address[] calldata _signers,
        uint256[] calldata _powers
    ) external returns (bytes32);
}
