// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../lib/Signature.sol";
import "../interface/ICBridge.sol";
import "../interface/IL1StandardBridge.sol";
import "../interface/IL2StandardERC20.sol";

contract Bridge is PausableUpgradeable, AccessControlEnumerableUpgradeable {
    using Signature for bytes32;

    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    event Relay(
        bytes32 transferId,
        address sender,
        address receiver,
        address token,
        uint256 amount,
        uint64 srcChainId,
        bytes32 srcTransferId
    );

    struct RelayRequest {
        address sender;
        address receiver;
        address srcToken;
        address dstToken;
        address hubToken;
        uint256 amount;
        uint64 srcChainId;
        uint64 dstChainId;
        bytes32 srcTransferId;
    }

    address public OVM_OAS;
    address public L2_STANDARD_BRIDGE;

    ICBridge private _cbridge;

    // Verse chain id => Proxy__OVM_L1StandardBridge
    mapping(uint => IL1StandardBridge) private _verseBridge;

    mapping(bytes32 => bool) private _transfers;

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

    function initialize(address oas_, address l2Bridge_) public initializer {
        __Pausable_init();
        __AccessControlEnumerable_init();

        OVM_OAS = oas_;
        L2_STANDARD_BRIDGE = l2Bridge_;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    function _setVerseBridge(uint256 chainId, address bridge) internal {
        _verseBridge[chainId] = IL1StandardBridge(bridge);
    }

    function setVerseBridge(
        uint256 chainId,
        address bridge
    ) external onlyOperator {
        _setVerseBridge(chainId, bridge);
    }

    function _setCBridge(address cbridge) internal {
        _cbridge = ICBridge(cbridge);
    }

    function setCBridge(address cbridge) external onlyOperator {
        _setCBridge(cbridge);
    }

    function pause() public onlyPauser {
        _pause();
    }

    function unpause() public onlyPauser {
        _unpause();
    }

    function _verifySigs(
        bytes memory _msg,
        bytes[] calldata _sigs,
        address[] calldata _signers
    ) internal pure {
        bytes32 hashMessage = keccak256(_msg).prefixed();
        for (uint256 i = 0; i < _sigs.length; i++) {
            require(
                hashMessage.recoverSigner(_sigs[i]) == _signers[i],
                "invalid signer"
            );
        }
    }

    function relayExternalRequest(
        RelayRequest calldata _relayRequest,
        bytes[] calldata _sigs,
        address[] calldata _signers
    ) external whenNotPaused {
        bytes32 domain = keccak256(
            abi.encodePacked(block.chainid, address(this), "Relay")
        );
        _verifySigs(
            abi.encodePacked(domain, abi.encode(_relayRequest)),
            _sigs,
            _signers
        );

        bytes32 transferId = keccak256(
            abi.encodePacked(
                _relayRequest.sender,
                _relayRequest.receiver,
                _relayRequest.srcToken,
                _relayRequest.dstToken,
                _relayRequest.hubToken,
                _relayRequest.amount,
                _relayRequest.srcChainId,
                _relayRequest.dstChainId,
                _relayRequest.srcTransferId
            )
        );

        _cbridge.send(
            _relayRequest.receiver,
            _relayRequest.hubToken,
            _relayRequest.amount,
            _relayRequest.dstChainId,
            uint64(uint256(transferId)),
            780
        );

        emit Relay(
            transferId,
            _relayRequest.sender,
            _relayRequest.receiver,
            _relayRequest.dstToken,
            _relayRequest.amount,
            _relayRequest.srcChainId,
            transferId
        );
    }

    function relayVerseRequest(
        RelayRequest calldata _relayRequest,
        bytes[] calldata _sigs,
        address[] calldata _signers
    ) external whenNotPaused {
        bytes32 domain = keccak256(
            abi.encodePacked(block.chainid, address(this), "Relay")
        );
        _verifySigs(
            abi.encodePacked(domain, abi.encode(_relayRequest)),
            _sigs,
            _signers
        );

        IL1StandardBridge bridge = _verseBridge[_relayRequest.dstChainId];

        bytes32 transferId = keccak256(
            abi.encodePacked(
                _relayRequest.sender,
                _relayRequest.receiver,
                _relayRequest.srcToken,
                _relayRequest.dstToken,
                _relayRequest.hubToken,
                _relayRequest.amount,
                _relayRequest.srcChainId,
                _relayRequest.dstChainId,
                _relayRequest.srcTransferId
            )
        );
        require(_transfers[transferId] == false, "Bridge: transfer exists");
        _transfers[transferId] = true;

        if (_relayRequest.srcToken == OVM_OAS) {
            bridge.depositETHTo{value: _relayRequest.amount}(
                _relayRequest.receiver,
                2_000_000,
                "0x"
            );
        } else {
            IERC20(_relayRequest.hubToken).approve(
                address(bridge),
                _relayRequest.amount
            );
            bridge.depositERC20To(
                _relayRequest.hubToken,
                _relayRequest.dstToken,
                _relayRequest.receiver,
                _relayRequest.amount,
                2_000_000,
                "0x"
            );
        }

        emit Relay(
            transferId,
            _relayRequest.sender,
            _relayRequest.receiver,
            _relayRequest.dstToken,
            _relayRequest.amount,
            _relayRequest.srcChainId,
            transferId
        );
    }
}
