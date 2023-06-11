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

  // token address => is protected
  mapping(address => bool) private _protectedToken;

  // game address => true
  mapping(address => bool) private _registeredGame;

  address[] private _tokenList;

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

  modifier requireWhitelisted() {
    require(_registeredGame[_msgSender()], "Oracle: caller is not whitelisted");
    _;
  }

  function initialize() public initializer {
    __AccessControlEnumerable_init();

    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(OPERATOR_ROLE, _msgSender());
  }

  function addProtectedToken(address token_) public onlyAdmin {
    _protectedToken[token_] = true;
    _tokenList.push(token_);
  }

  function removeProtectedToken(address token_) public onlyAdmin {
    _protectedToken[token_] = false;
    for (uint i = 0; i < _tokenList.length; i++) {
      if (_tokenList[i] == token_) {
        _tokenList[i] = address(0);
      }
    }
  }

  function isProtectedToken(address token_) public view returns (bool) {
    return _protectedToken[token_];
  }

  function setWhitelist(address addr_, bool isWhitelist_) public onlyAdmin {
    _registeredGame[addr_] = isWhitelist_;
  }

  function isWhitelisted(address addr_) public view returns (bool) {
    return _registeredGame[addr_];
  }

  function getProtectedTokens() public view returns (address[] memory) {
    return _tokenList;
  }

  function updateEarn(
    address user_,
    address token_,
    uint256 amount_
  ) public requireWhitelisted {
    _userEarned[user_][token_] = amount_ + _userEarned[user_][token_];

    emit TokenEarned(msg.sender, user_, token_, amount_);
  }

  function updateSold(address user_, address token_, uint256 amount_) public {
    _userSold[user_][token_] = amount_ + _userSold[user_][token_];

    emit TokenSold(msg.sender, user_, token_, amount_);
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
