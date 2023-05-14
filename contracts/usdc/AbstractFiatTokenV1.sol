// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract AbstractFiatTokenV1 is IERC20 {
  function _approve(
    address owner,
    address spender,
    uint256 value
  ) internal virtual;

  function _transfer(
    address from,
    address to,
    uint256 value
  ) internal virtual;
}
