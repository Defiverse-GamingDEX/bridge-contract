// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IStakingLiquidityGauge.sol";
import "./ILiquidityGaugeFactory.sol";

interface IGaugeAdder {
  enum GaugeType { LiquidityMiningCommittee, veBAL, Ethereum, Polygon, Arbitrum, Optimism, Gnosis, ZKSync }

  function addEthereumGauge(IStakingLiquidityGauge gauge) external;

  function isGaugeFromValidFactory(address gauge, GaugeType gaugeType) external view returns (bool);

  function addGaugeFactory(ILiquidityGaugeFactory factory, GaugeType gaugeType) external;
}
