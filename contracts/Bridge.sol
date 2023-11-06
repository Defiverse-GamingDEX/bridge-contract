// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./lib/Signature.sol";
import "./interface/ICBridge.sol";
import "./interface/IL1StandardBridge.sol";
import "./interface/IL2StandardERC20.sol";

contract Bridge is PausableUpgradeable, AccessControlEnumerableUpgradeable {
    using Signature for bytes32;

    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    uint256 public constant A_HUNDRED_PERCENT = 10_000; // 100%

    event AddSigner(address signer);

    event RevokeSigner(address signer);

    event Relay(
        bytes32 transferId,
        address receiver,
        address token,
        uint256 amountOut,
        bytes32 srcTransferId
    );

    struct RelayRequest {
        address sender;
        address receiver;
        address token; // Layer 1 token
        address l2Token; // Layer 2 token, address(0) if external chain
        uint256 amount;
        uint64 srcChainId;
        uint64 dstChainId;
        bytes32 srcTransferId;
    }

    uint32 private _minSigner;
    uint32 private _signerCount;
    mapping(address => bool) private _signers;

    address public OVM_OAS;
    address public L2_STANDARD_BRIDGE;

    ICBridge private _cbridge;

    // Verse chain id => Proxy__OVM_L1StandardBridge
    mapping(uint => IL1StandardBridge) private _verseBridge;

    mapping(bytes32 => bool) private _transfers;

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

    modifier onlySigners(address[] calldata signers) {
        for (uint i = 0; i < signers.length; i++) {
            require(hasRole(SIGNER_ROLE, signers[i]), "INVALID_SIGNER");
        }
        _;
    }

    function initialize(
        address oas_,
        address l2Bridge_,
        address feeReceiver_
    ) public initializer {
        __Pausable_init();
        __AccessControlEnumerable_init();

        _minSigner = 3;
        _feeReceiver = feeReceiver_;

        OVM_OAS = oas_;
        L2_STANDARD_BRIDGE = l2Bridge_;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    receive() external payable {}

    function addSigner(address signer) external onlyAdmin {
        require(!_signers[signer], "Bridge: signer is existed!");
        _signers[signer] = true;
        _setupRole(SIGNER_ROLE, signer);
        _signerCount += 1;
        emit AddSigner(signer);
    }

    function revokeSigner(address signer) external onlyAdmin {
        require(_signers[signer], "Bridge: signer is not existed!");
        revokeRole(SIGNER_ROLE, signer);
        _signers[signer] = false;
        _signerCount -= 1;
        emit RevokeSigner(signer);
    }

    function setMinSigner(uint32 min) external onlyAdmin {
        _minSigner = min;
    }

    function getMinSigner() external view returns (uint32) {
        return _minSigner;
    }

    function getSignerCount() external view returns (uint32) {
        return _signerCount;
    }

    function isSignerExists(address signer) external view returns (bool) {
        return _signers[signer];
    }

    function getSwapFeeRate(
        address token,
        uint256 chainId
    ) external view returns (uint256) {
        return _swapFeeRate[token][chainId];
    }

    function setSwapFeeRate(
        address token,
        uint256 chainId,
        uint256 feeRate
    ) external onlyAdmin {
        _swapFeeRate[token][chainId] = feeRate;
    }

    function getBaseFee(
        address token,
        uint256 chainId
    ) external view returns (uint256) {
        return _baseFee[token][chainId];
    }

    function setBaseFee(
        address token,
        uint256 chainId,
        uint256 fee
    ) external onlyAdmin {
        _baseFee[token][chainId] = fee;
    }

    function setFeeReceiver(address addr) external onlyAdmin {
        _feeReceiver = addr;
    }

    function getFeeReceiver() external view returns (address) {
        return _feeReceiver;
    }

    function _setVerseBridge(uint256 chainId, address bridge) internal {
        _verseBridge[chainId] = IL1StandardBridge(bridge);
    }

    function setVerseBridge(
        uint256 chainId,
        address bridge
    ) external onlyAdmin {
        _setVerseBridge(chainId, bridge);
    }

    function _setCBridge(address cbridge) internal {
        _cbridge = ICBridge(cbridge);
    }

    function setCBridge(address cbridge) external onlyAdmin {
        _setCBridge(cbridge);
    }

    function pause() external onlyPauser {
        _pause();
    }

    function unpause() external onlyPauser {
        _unpause();
    }

    function relayExternalRequest(
        RelayRequest calldata relayRequest_,
        bytes[] calldata sigs_,
        address[] calldata signers_
    ) external onlyOperator onlySigners(signers_) whenNotPaused {
        require(sigs_.length >= _minSigner, "Bridge: not meet threshold");
        bytes32 transferId = keccak256(
            abi.encodePacked(
                relayRequest_.sender,
                relayRequest_.receiver,
                relayRequest_.token,
                relayRequest_.amount,
                relayRequest_.srcChainId,
                relayRequest_.dstChainId,
                relayRequest_.srcTransferId
            )
        );
        require(_transfers[transferId] == false, "Bridge: transfer exists");

        transferId.verifySignatures(sigs_, signers_);

        (uint256 amountOut, uint256 fee) = _calculateFee(
            relayRequest_.token,
            relayRequest_.dstChainId,
            relayRequest_.amount
        );

        if (relayRequest_.token == OVM_OAS) {
            _cbridge.sendNative(
                relayRequest_.receiver,
                amountOut,
                relayRequest_.dstChainId,
                uint64(uint256(transferId)),
                780
            );
            if (fee > 0) {
                (bool success, ) = payable(_feeReceiver).call{value: fee}("");
                require(success, "Bridge: failure to transfer fee");
            }
        } else {
            IERC20(relayRequest_.token).approve(address(_cbridge), amountOut);
            _cbridge.send(
                relayRequest_.receiver,
                relayRequest_.token,
                amountOut,
                relayRequest_.dstChainId,
                uint64(uint256(transferId)),
                780
            );
            if (fee > 0) {
                IERC20(relayRequest_.token).transfer(_feeReceiver, fee);
            }
        }

        _transfers[transferId] = true;

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
    ) external onlyOperator onlySigners(signers_) whenNotPaused {
        require(sigs_.length >= _minSigner, "Bridge: not meet threshold");

        bytes32 transferId = keccak256(
            abi.encodePacked(
                relayRequest_.sender,
                relayRequest_.receiver,
                relayRequest_.token,
                relayRequest_.amount,
                relayRequest_.srcChainId,
                relayRequest_.dstChainId,
                relayRequest_.srcTransferId
            )
        );
        require(_transfers[transferId] == false, "Bridge: transfer exists");
        transferId.verifySignatures(sigs_, signers_);

        (uint256 amountOut, uint256 fee) = _calculateFee(
            relayRequest_.token,
            relayRequest_.dstChainId,
            relayRequest_.amount
        );

        IL1StandardBridge bridge = _verseBridge[relayRequest_.dstChainId];
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
            IERC20(relayRequest_.token).approve(address(bridge), amountOut);
            bridge.depositERC20To(
                relayRequest_.token,
                relayRequest_.l2Token,
                relayRequest_.receiver,
                amountOut,
                2_000_000,
                "0x"
            );
            if (fee > 0) {
                IERC20(relayRequest_.token).transfer(_feeReceiver, fee);
            }
        }

        _transfers[transferId] = true;

        emit Relay(
            transferId,
            relayRequest_.receiver,
            relayRequest_.token,
            amountOut,
            relayRequest_.srcTransferId
        );
    }

    function estimateFee(
        address token,
        uint256 dstChainId,
        uint256 amountIn
    ) external view returns (uint256 amountOut, uint256 fee) {
        return _calculateFee(token, amountIn, dstChainId);
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
