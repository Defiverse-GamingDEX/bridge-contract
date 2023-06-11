// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IBALTokenHolder.sol";

interface IBALTokenHolderFactory {
  function create(string memory name) external returns (IBALTokenHolder);
}
