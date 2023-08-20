// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./interface/IOracle.sol";

contract OracleSample {
  IERC20 private _gameToken;
  IOracle private _oracle;

  constructor(address gameToken_, address oracle_) {
    _gameToken = IERC20(gameToken_);
    _oracle = IOracle(oracle_);
  }

  /**
   * Call when the user receives the reward on the game
   * @param user_ user address
   * @param amount_ reward amount
   */
  function _onEarn(address user_, uint256 amount_) internal {
    _oracle.updateEarn(user_, address(_gameToken), amount_);
  }
}
