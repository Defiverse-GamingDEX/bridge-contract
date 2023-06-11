// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface IGaugeController {
  function add_type(string calldata name, uint256 weight) external;
  function add_gauge(address gauge, int128 gaugeType) external;
}
