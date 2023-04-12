// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGPT4veDFV {
  event Locked(address user_, uint256 amount_, uint256 lockPeriod_);
  event Unlocked(address user_, uint256 amount_);

  function lockGPT(uint256 amount_, uint256 lockPeriod_) external;

  function unlockGPT() external;

  function extendGPT(uint256 amount_) external;

  function extendLockPeriod(uint256 lockPeriod_) external;
}
