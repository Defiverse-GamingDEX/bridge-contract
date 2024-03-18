// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interface/IWETH.sol";

contract MockCBridge {
    using SafeERC20 for IERC20;

    event Send(
        bytes32 transferId,
        address sender,
        address receiver,
        address token,
        uint256 amount,
        uint64 dstChainId,
        uint64 nonce,
        uint32 maxSlippage
    );

    event Relay(
        bytes32 transferId,
        address sender,
        address receiver,
        address token,
        uint256 amount,
        uint64 srcChainId,
        bytes32 srcTransferId
    );

    mapping(bytes32 => bool) public transfers;
    mapping(address => uint256) public minSend; // send _amount must > minSend
    mapping(address => uint256) public maxSend;

    uint32 public minimalMaxSlippage;

    address public nativeWrap;

    constructor(address _nativeWrap) {
        nativeWrap = _nativeWrap;
    }

    function send(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage
    ) external {
        bytes32 transferId = _send(
            _receiver,
            _token,
            _amount,
            _dstChainId,
            _nonce,
            _maxSlippage
        );
        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        emit Send(
            transferId,
            msg.sender,
            _receiver,
            _token,
            _amount,
            _dstChainId,
            _nonce,
            _maxSlippage
        );
    }

    function sendNative(
        address _receiver,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage
    ) external payable {
        require(msg.value == _amount, "Amount mismatch");
        require(nativeWrap != address(0), "Native wrap not set");
        bytes32 transferId = _send(
            _receiver,
            nativeWrap,
            _amount,
            _dstChainId,
            _nonce,
            _maxSlippage
        );
        IWETH(nativeWrap).deposit{value: _amount}();
        emit Send(
            transferId,
            msg.sender,
            _receiver,
            nativeWrap,
            _amount,
            _dstChainId,
            _nonce,
            _maxSlippage
        );
    }

    function _send(
        address _receiver,
        address _token,
        uint256 _amount,
        uint64 _dstChainId,
        uint64 _nonce,
        uint32 _maxSlippage
    ) private returns (bytes32) {
        bytes32 transferId = keccak256(
            // uint64(block.chainid) for consistency as entire system uses uint64 for chain id
            // len = 20 + 20 + 20 + 32 + 8 + 8 + 8 = 116
            abi.encodePacked(
                msg.sender,
                _receiver,
                _token,
                _amount,
                _dstChainId,
                _nonce,
                uint64(block.chainid)
            )
        );
        require(transfers[transferId] == false, "transfer exists");
        transfers[transferId] = true;
        return transferId;
    }
}
