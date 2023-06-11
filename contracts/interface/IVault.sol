// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./IAuthorizer.sol";

interface IVault {
  function getAuthorizer() external view returns (IAuthorizer);
}
