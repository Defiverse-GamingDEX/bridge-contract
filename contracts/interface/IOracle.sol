// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IOracle {
  function updateEarn(address user_, address token_, uint256 amount_) external;

  function updateSold(address user_, address token_, uint256 amount_) external;

  function getSellable(
    address user_,
    address token_
  ) external returns (uint256);
}
