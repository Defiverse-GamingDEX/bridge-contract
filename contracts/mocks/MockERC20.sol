// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) ERC20(name, symbol) {
        _mint(msg.sender, supply);
    }

    function mintTokens(uint256 _amount) public {
        _mint(msg.sender, _amount);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}
