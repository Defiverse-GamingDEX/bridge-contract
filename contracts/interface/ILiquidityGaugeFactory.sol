// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ILiquidityGaugeFactory {
  function isGaugeFromFactory(address gauge) external view returns (bool);

  function create(
    address recipient,
    uint256 relativeWeightCap,
    bool feeDistributorRecipient
  ) external returns (address);

  function create(
    address pool,
    uint256 relativeWeightCap
  ) external returns (address);
}
