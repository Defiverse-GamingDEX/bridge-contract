// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./lib/Signature.sol";
import "./interface/IBridge.sol";
import "./interface/ICBridge.sol";
import "./interface/IL1StandardBridge.sol";
import "./interface/IL2StandardERC20.sol";

contract Bridge is
    IBridge,
    PausableUpgradeable,
    AccessControlEnumerableUpgradeable
{
    using Signature for bytes32;
    using SafeERC20 for IERC20;

    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public constant A_HUNDRED_PERCENT = 10_000; // 100%

    uint256 private _minSigner;

    address public OVM_OAS;
    address public L2_STANDARD_BRIDGE;

    ICBridge private _cbridge;

    // Verse chain id => Proxy__OVM_L1StandardBridge
    mapping(uint => IL1StandardBridge) private _verseBridge;

    // transfer id => true | false
    mapping(bytes32 => bool) private _transfers;

    // withdrawal id => true | false
    mapping(bytes32 => bool) private _withdrawals;

    // token address => destination chainid => swap fee rate, [0..2] percents
    mapping(address => mapping(uint256 => uint256)) private _swapFeeRate;

    // token address => destination chainid => base fee, fixed fee
    mapping(address => mapping(uint256 => uint256)) private _baseFee;

    address private _feeReceiver;

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Bridge: caller is not admin"
        );
        _;
    }

    modifier onlyOperator() {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            "Bridge: caller is not operator"
        );
        _;
    }

    modifier onlyPauser() {
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            "Bridge: caller is not pauser"
        );
        _;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address oas_,
        address l2Bridge_,
        address feeReceiver_,
        uint256 minSigner_,
        address admin_
    ) public initializer {
        __Pausable_init();
        __AccessControlEnumerable_init();

        _minSigner = minSigner_;
        _feeReceiver = feeReceiver_;

        OVM_OAS = oas_;
        L2_STANDARD_BRIDGE = l2Bridge_;

        _setupRole(DEFAULT_ADMIN_ROLE, admin_);
        _setupRole(OPERATOR_ROLE, admin_);
        _setupRole(PAUSER_ROLE, admin_);
    }

    receive() external payable {}

    function addSigner(address signer) external override onlyAdmin {
        require(!hasRole(SIGNER_ROLE, signer), "Bridge: signer is existed!");
        _setupRole(SIGNER_ROLE, signer);
        emit AddSigner(signer);
    }

    function revokeSigner(address signer) external override onlyAdmin {
        require(hasRole(SIGNER_ROLE, signer), "Bridge: signer is not existed!");
        revokeRole(SIGNER_ROLE, signer);
        emit RevokeSigner(signer);
    }

    function setMinSigner(uint256 min) external override onlyAdmin {
        require(
            min > 0 && min <= getRoleMemberCount(SIGNER_ROLE),
            "Bridge: value must greater than zero and less than or equal to signer count"
        );
        _minSigner = min;
    }

    function getMinSigner() external view override returns (uint256) {
        return _minSigner;
    }

    function getSignerCount() external view override returns (uint256) {
        return getRoleMemberCount(SIGNER_ROLE);
    }

    function isSignerExists(
        address signer
    ) external view override returns (bool) {
        return hasRole(SIGNER_ROLE, signer);
    }

    function getSwapFeeRate(
        address token,
        uint256 chainId
    ) external view override returns (uint256) {
        return _swapFeeRate[token][chainId];
    }

    function setSwapFeeRate(
        address token,
        uint256 chainId,
        uint256 feeRate
    ) external override onlyOperator {
        _swapFeeRate[token][chainId] = feeRate;
    }

    function getBaseFee(
        address token,
        uint256 chainId
    ) external view override returns (uint256) {
        return _baseFee[token][chainId];
    }

    function setBaseFee(
        address token,
        uint256 chainId,
        uint256 fee
    ) external override onlyOperator {
        _baseFee[token][chainId] = fee;
    }

    function setFeeReceiver(address addr) external override onlyAdmin {
        _feeReceiver = addr;
    }

    function getFeeReceiver() external view override returns (address) {
        return _feeReceiver;
    }

    function _setVerseBridge(uint256 chainId, address bridge) internal {
        require(bridge != address(0), "Bridge: invalid address");
        _verseBridge[chainId] = IL1StandardBridge(bridge);
    }

    function setVerseBridge(
        uint256 chainId,
        address bridge
    ) external override onlyAdmin {
        _setVerseBridge(chainId, bridge);
    }

    function _setCBridge(address cbridge) internal {
        require(cbridge != address(0), "Bridge: invalid address");
        _cbridge = ICBridge(cbridge);
    }

    function setCBridge(address cbridge) external override onlyAdmin {
        _setCBridge(cbridge);
    }

    function pause() external override onlyPauser {
        _pause();
    }

    function unpause() external override onlyPauser {
        _unpause();
    }

    function _verifySigners(address[] calldata signers_) internal view {
        require(signers_.length >= _minSigner, "Bridge: not meet threshold");

        for (uint i = 0; i < signers_.length; i++) {
            require(hasRole(SIGNER_ROLE, signers_[i]), "INVALID_SIGNER");

            // Check duplicate signer
            for (uint j = i + 1; j < signers_.length; j++) {
                if (signers_[i] == signers_[j]) {
                    revert("Bridge: duplicate signer");
                }
            }
        }
    }

    function _verifyRelayRequest(
        RelayRequest calldata relayRequest_,
        bytes[] calldata sigs_,
        address[] calldata signers_
    ) internal view returns (bytes32) {
        _verifySigners(signers_);

        bytes32 transferId = keccak256(
            abi.encodePacked(
                relayRequest_.sender,
                relayRequest_.receiver,
                relayRequest_.token,
                relayRequest_.l2Token,
                relayRequest_.amount,
                relayRequest_.srcChainId,
                relayRequest_.dstChainId,
                relayRequest_.srcTransferId
            )
        );

        require(_transfers[transferId] == false, "Bridge: transfer exists");
        transferId.verifySignatures(sigs_, signers_);
        return transferId;
    }

    function _verifyWithdrawRequest(
        WithdrawRequest calldata relayRequest_,
        bytes[] calldata sigs_,
        address[] calldata signers_
    ) internal view returns (bytes32) {
        _verifySigners(signers_);

        bytes32 withdrawId = keccak256(
            abi.encodePacked(
                relayRequest_.receiver,
                relayRequest_.token,
                relayRequest_.amount,
                relayRequest_.srcChainId,
                relayRequest_.dstChainId,
                relayRequest_.srcTransferId
            )
        );
        require(_withdrawals[withdrawId] == false, "Bridge: withdraw exists");
        withdrawId.verifySignatures(sigs_, signers_);
        return withdrawId;
    }

    function relayExternalRequest(
        RelayRequest calldata relayRequest_,
        uint32 maxSlippage_,
        bytes[] calldata sigs_,
        address[] calldata signers_
    ) external override onlyOperator whenNotPaused {
        // The max slippage accepted, given as percentage in point (pip). Eg. 5000 means 0.5%.
        require(maxSlippage_ <= 1000000, "Bridge: max slippage too large");
        require(
            address(_cbridge) != address(0),
            "Bridge: destination chain does not supported"
        );
        bytes32 transferId = _verifyRelayRequest(
            relayRequest_,
            sigs_,
            signers_
        );

        (uint256 amountOut, uint256 fee) = _calculateFee(
            relayRequest_.token,
            relayRequest_.dstChainId,
            relayRequest_.amount
        );
        require(amountOut > 0, "Bridge: amount too small");

        _transfers[transferId] = true;

        if (relayRequest_.token == OVM_OAS) {
            _cbridge.sendNative{value: amountOut}(
                relayRequest_.receiver,
                amountOut,
                relayRequest_.dstChainId,
                uint64(uint256(transferId)),
                maxSlippage_
            );
            if (fee > 0) {
                (bool success, ) = payable(_feeReceiver).call{value: fee}("");
                require(success, "Bridge: failure to transfer fee");
            }
        } else {
            IERC20(relayRequest_.token).safeApprove(
                address(_cbridge),
                amountOut
            );
            _cbridge.send(
                relayRequest_.receiver,
                relayRequest_.token,
                amountOut,
                relayRequest_.dstChainId,
                uint64(uint256(transferId)),
                maxSlippage_
            );
            if (fee > 0) {
                IERC20(relayRequest_.token).safeTransfer(_feeReceiver, fee);
            }
        }

        emit Relay(
            transferId,
            relayRequest_.receiver,
            relayRequest_.token,
            amountOut,
            relayRequest_.srcTransferId
        );
    }

    function relayVerseRequest(
        RelayRequest calldata relayRequest_,
        bytes[] calldata sigs_,
        address[] calldata signers_
    ) external override onlyOperator whenNotPaused {
        bytes32 transferId = _verifyRelayRequest(
            relayRequest_,
            sigs_,
            signers_
        );
        IL1StandardBridge bridge = _verseBridge[relayRequest_.dstChainId];
        require(
            address(bridge) != address(0),
            "Bridge: destination chain does not supported"
        );

        (uint256 amountOut, uint256 fee) = _calculateFee(
            relayRequest_.token,
            relayRequest_.dstChainId,
            relayRequest_.amount
        );
        require(amountOut > 0, "Bridge: amount too small");

        _transfers[transferId] = true;

        if (relayRequest_.token == OVM_OAS) {
            bridge.depositETHTo{value: amountOut}(
                relayRequest_.receiver,
                2_000_000,
                "0x"
            );
            if (fee > 0) {
                (bool success, ) = payable(_feeReceiver).call{value: fee}("");
                require(success, "Bridge: failure to transfer fee");
            }
        } else {
            IERC20(relayRequest_.token).safeApprove(address(bridge), amountOut);
            bridge.depositERC20To(
                relayRequest_.token,
                relayRequest_.l2Token,
                relayRequest_.receiver,
                amountOut,
                2_000_000,
                "0x"
            );
            if (fee > 0) {
                IERC20(relayRequest_.token).safeTransfer(_feeReceiver, fee);
            }
        }

        emit Relay(
            transferId,
            relayRequest_.receiver,
            relayRequest_.token,
            amountOut,
            relayRequest_.srcTransferId
        );
    }

    function withdraw(
        WithdrawRequest calldata withdrawRequest_,
        bytes[] calldata sigs_,
        address[] calldata signers_
    ) external override onlyOperator whenNotPaused {
        bytes32 withdrawId = _verifyWithdrawRequest(
            withdrawRequest_,
            sigs_,
            signers_
        );

        _withdrawals[withdrawId] = true;

        if (withdrawRequest_.token == OVM_OAS) {
            (bool success, ) = payable(withdrawRequest_.receiver).call{
                value: withdrawRequest_.amount
            }("");
            require(success, "Bridge: failure to transfer");
        } else {
            IERC20(withdrawRequest_.token).safeTransfer(
                withdrawRequest_.receiver,
                withdrawRequest_.amount
            );
        }

        emit WithdrawDone(
            withdrawId,
            withdrawRequest_.receiver,
            withdrawRequest_.token,
            withdrawRequest_.amount,
            withdrawRequest_.srcTransferId
        );
    }

    function estimateFee(
        address token,
        uint256 dstChainId,
        uint256 amountIn
    ) external view override returns (uint256 amountOut, uint256 fee) {
        return _calculateFee(token, dstChainId, amountIn);
    }

    function _calculateFee(
        address token,
        uint256 dstChainId,
        uint256 amountIn
    ) private view returns (uint256 amountOut, uint256 fee) {
        uint256 swapFee = (amountIn * _swapFeeRate[token][dstChainId]) /
            A_HUNDRED_PERCENT;
        fee = _baseFee[token][dstChainId] + swapFee;

        if (fee > amountIn) {
            fee = amountIn;
            amountOut = 0;
        } else {
            amountOut = amountIn - fee;
        }

        return (amountOut, fee);
    }
}
