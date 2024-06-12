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

    uint256 private _minSigner;

    address public OVM_OAS;

    ICBridge private _cbridge;

    // Verse chain id => Proxy__OVM_L1StandardBridge
    mapping(uint => IL1StandardBridge) private _verseBridge;

    // transfer id => true | false
    mapping(bytes32 => bool) private _transfers;

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
        address feeReceiver_,
        uint256 minSigner_,
        address admin_
    ) public initializer {
        require(minSigner_ > 0, "Bridge: minSigner must be greater than 0");

        __Pausable_init();
        __AccessControlEnumerable_init();

        _minSigner = minSigner_;
        _feeReceiver = feeReceiver_;
        OVM_OAS = oas_;

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
                relayRequest_.fee,
                relayRequest_.amount,
                relayRequest_.nativeTokenAmount,
                relayRequest_.dstChainId,
                relayRequest_.srcTransferId
            )
        );

        require(_transfers[transferId] == false, "Bridge: transfer exists");
        transferId.verifySignatures(sigs_, signers_);
        return transferId;
    }

    function relayExternalRequest(
        RelayRequest calldata relayRequest_,
        uint32 maxSlippage_,
        bytes[] calldata sigs_,
        address[] calldata signers_
    ) external override onlyOperator whenNotPaused {
        require(relayRequest_.amount > 0, "Bridge: amount too small");
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

        _transfers[transferId] = true;

        if (relayRequest_.token == OVM_OAS) {
            _cbridge.sendNative{value: relayRequest_.amount}(
                relayRequest_.receiver,
                relayRequest_.amount,
                relayRequest_.dstChainId,
                uint64(uint256(transferId)),
                maxSlippage_
            );
            if (relayRequest_.fee > 0) {
                (bool success, ) = payable(_feeReceiver).call{
                    value: relayRequest_.fee
                }("");
                require(success, "Bridge: failure to transfer fee");
            }
        } else {
            IERC20(relayRequest_.token).safeIncreaseAllowance(
                address(_cbridge),
                relayRequest_.amount
            );
            _cbridge.send(
                relayRequest_.receiver,
                relayRequest_.token,
                relayRequest_.amount,
                relayRequest_.dstChainId,
                uint64(uint256(transferId)),
                maxSlippage_
            );
            if (relayRequest_.fee > 0) {
                IERC20(relayRequest_.token).safeTransfer(
                    _feeReceiver,
                    relayRequest_.fee
                );
            }
        }

        emit Relay(
            transferId,
            relayRequest_.receiver,
            relayRequest_.token,
            relayRequest_.fee,
            relayRequest_.amount,
            relayRequest_.nativeTokenAmount,
            relayRequest_.srcTransferId
        );
    }

    function relayVerseRequest(
        RelayRequest calldata relayRequest_,
        uint32 gasLimit_, // default 2_000_000
        bytes[] calldata sigs_,
        address[] calldata signers_
    ) external override onlyOperator whenNotPaused {
        require(relayRequest_.amount > 0, "Bridge: amount too small");

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

        _transfers[transferId] = true;

        if (relayRequest_.token == OVM_OAS) {
            bridge.depositETHTo{value: relayRequest_.amount}(
                relayRequest_.receiver,
                gasLimit_,
                "0x"
            );
            if (relayRequest_.fee > 0) {
                (bool success, ) = payable(_feeReceiver).call{
                    value: relayRequest_.fee
                }("");
                require(success, "Bridge: failure to transfer fee");
            }
        } else {
            IERC20(relayRequest_.token).safeIncreaseAllowance(
                address(bridge),
                relayRequest_.amount
            );
            bridge.depositERC20To(
                relayRequest_.token,
                relayRequest_.l2Token,
                relayRequest_.receiver,
                relayRequest_.amount,
                gasLimit_,
                "0x"
            );

            if (relayRequest_.nativeTokenAmount > 0) {
                bridge.depositETHTo{value: relayRequest_.nativeTokenAmount}(
                    relayRequest_.receiver,
                    gasLimit_,
                    "0x"
                );
            }

            if (relayRequest_.fee > 0) {
                IERC20(relayRequest_.token).safeTransfer(
                    _feeReceiver,
                    relayRequest_.fee
                );
            }
        }

        emit Relay(
            transferId,
            relayRequest_.receiver,
            relayRequest_.token,
            relayRequest_.fee,
            relayRequest_.amount,
            relayRequest_.nativeTokenAmount,
            relayRequest_.srcTransferId
        );
    }
}
