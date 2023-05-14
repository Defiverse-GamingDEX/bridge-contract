// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./interface/IOracle.sol";

contract Oracle is IOracle, AccessControlEnumerableUpgradeable {
  bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

  // user => token => earned amount
  mapping(address => mapping(address => uint256)) private _userEarned;

  // user => token => sold amount
  mapping(address => mapping(address => uint256)) private _userSold;

  uint256 MAX_INT =
    115792089237316195423570985008687907853269984665640564039457584007913129639935;

  mapping(address => bool) private _protectedToken;

  modifier onlyAdmin() {
    require(
      hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
      "Oracle: caller is not admin"
    );
    _;
  }

  modifier onlyOperator() {
    require(
      hasRole(OPERATOR_ROLE, _msgSender()),
      "Oracle: caller is not operator"
    );
    _;
  }

  function initialize() public initializer {
    __AccessControlEnumerable_init();

    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(OPERATOR_ROLE, _msgSender());
  }

  function addProtectedToken(address token_) public onlyAdmin {
    _protectedToken[token_] = true;
  }

  function removeProtectedToken(address token_) public onlyAdmin {
    _protectedToken[token_] = false;
  }

  function isProtectedToken(address token_) public view returns (bool) {
    return _protectedToken[token_];
  }

  function updateEarn(
    address user_,
    address token_,
    uint256 amount_
  ) public onlyOperator {
    _userEarned[user_][token_] = amount_ + _userEarned[user_][token_];
  }

  function updateSold(
    address user_,
    address token_,
    uint256 amount_
  ) public onlyOperator {
    _userSold[user_][token_] = amount_ + _userSold[user_][token_];
  }

  function getSellable(
    address user_,
    address token_
  ) public view returns (uint256) {
    if (!_protectedToken[token_]) {
      return 10000000000000000000000000000;
    }

    uint256 earned = _userEarned[user_][token_];
    uint256 sold = _userSold[user_][token_];
    if (sold >= earned) return 0;
    return earned - sold;
  }
}
