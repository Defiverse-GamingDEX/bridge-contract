// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IOracle {
  event TokenEarned(
    address indexed from,
    address indexed user,
    address indexed token,
    uint256 amount
  );

  event TokenSold(
    address indexed from,
    address indexed user,
    address indexed token,
    uint256 amount
  );

  function updateEarn(address user_, address token_, uint256 amount_) external;

  function updateSold(address user_, address token_, uint256 amount_) external;

  function getSellable(
    address user_,
    address token_
  ) external returns (uint256);
}
