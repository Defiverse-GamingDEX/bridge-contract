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

    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    event AddSigner(address signer);

    event RevokeSigner(address signer);

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

    uint32 private _minSigner;
    uint32 private _signerCount;
    mapping(address => bool) private _signers;

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

        _minSigner = 3;
        OVM_OAS = oas_;
        L2_STANDARD_BRIDGE = l2Bridge_;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    function addSigner(address signer) public onlyAdmin {
        require(!_signers[signer], "Bridge: signer is existed!");
        _signers[signer] = true;
        _setupRole(SIGNER_ROLE, signer);
        _signerCount += 1;
        emit AddSigner(signer);
    }

    function revokeSigner(address signer) public onlyAdmin {
        require(_signers[signer], "Bridge: signer is not existed!");
        revokeRole(SIGNER_ROLE, signer);
        _signers[signer] = false;
        _signerCount -= 1;
        emit RevokeSigner(signer);
    }

    function setMinSigner(uint32 min) public onlyAdmin {
        _minSigner = min;
    }

    function getMinSigner() public view returns (uint32) {
        return _minSigner;
    }

    function getSignerCount() public view returns (uint32) {
        return _signerCount;
    }

    function isSignerExists(address signer) public view returns (bool) {
        return _signers[signer];
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
        bytes memory msg_,
        bytes[] calldata sigs_,
        address[] calldata signers_
    ) internal view {
        require(signers_.length >= _minSigner, "Bridge: not enough signers");

        bytes32 message = keccak256(msg_).prefixed();
        for (uint256 i = 0; i < sigs_.length; i++) {
            address signer = message.recoverSigner(sigs_[i]);
            require(
                _signers[signer] && signer == signers_[i],
                "Bridge: invalid signature"
            );
        }
    }

    function relayExternalRequest(
        RelayRequest calldata relayRequest_,
        bytes[] calldata sigs_,
        address[] calldata signers_
    ) external whenNotPaused {
        bytes32 domain = keccak256(
            abi.encodePacked(block.chainid, address(this), "Relay")
        );
        _verifySigs(
            abi.encodePacked(domain, abi.encode(relayRequest_)),
            sigs_,
            signers_
        );

        bytes32 transferId = keccak256(
            abi.encodePacked(
                relayRequest_.sender,
                relayRequest_.receiver,
                relayRequest_.srcToken,
                relayRequest_.dstToken,
                relayRequest_.hubToken,
                relayRequest_.amount,
                relayRequest_.srcChainId,
                relayRequest_.dstChainId,
                relayRequest_.srcTransferId
            )
        );

        _cbridge.send(
            relayRequest_.receiver,
            relayRequest_.hubToken,
            relayRequest_.amount,
            relayRequest_.dstChainId,
            uint64(uint256(transferId)),
            780
        );

        emit Relay(
            transferId,
            relayRequest_.sender,
            relayRequest_.receiver,
            relayRequest_.dstToken,
            relayRequest_.amount,
            relayRequest_.srcChainId,
            transferId
        );
    }

    function relayVerseRequest(
        RelayRequest calldata relayRequest_,
        bytes[] calldata sigs_,
        address[] calldata signers_
    ) external whenNotPaused {
        bytes32 domain = keccak256(
            abi.encodePacked(block.chainid, address(this), "Relay")
        );
        _verifySigs(
            abi.encodePacked(domain, abi.encode(relayRequest_)),
            sigs_,
            signers_
        );

        bytes32 transferId = keccak256(
            abi.encodePacked(
                relayRequest_.sender,
                relayRequest_.receiver,
                relayRequest_.srcToken,
                relayRequest_.dstToken,
                relayRequest_.hubToken,
                relayRequest_.amount,
                relayRequest_.srcChainId,
                relayRequest_.dstChainId,
                relayRequest_.srcTransferId
            )
        );
        require(_transfers[transferId] == false, "Bridge: transfer exists");
        _transfers[transferId] = true;

        IL1StandardBridge bridge = _verseBridge[relayRequest_.dstChainId];
        if (relayRequest_.srcToken == OVM_OAS) {
            bridge.depositETHTo{value: relayRequest_.amount}(
                relayRequest_.receiver,
                2_000_000,
                "0x"
            );
        } else {
            IERC20(relayRequest_.hubToken).approve(
                address(bridge),
                relayRequest_.amount
            );
            bridge.depositERC20To(
                relayRequest_.hubToken,
                relayRequest_.dstToken,
                relayRequest_.receiver,
                relayRequest_.amount,
                2_000_000,
                "0x"
            );
        }

        emit Relay(
            transferId,
            relayRequest_.sender,
            relayRequest_.receiver,
            relayRequest_.dstToken,
            relayRequest_.amount,
            relayRequest_.srcChainId,
            transferId
        );
    }
}
