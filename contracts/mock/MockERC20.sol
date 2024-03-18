// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract MockERC20 is AccessControlEnumerableUpgradeable, ERC20Upgradeable {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  modifier onlyAdmin() {
    require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "MockERC20: caller is not admin");
    _;
  }

  function initialize(string memory name, string memory symbol) public initializer {
    __AccessControlEnumerable_init();
    __ERC20_init(name, symbol);

    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(MINTER_ROLE, _msgSender());

    _mint(_msgSender(), 1000000000000000000000000);
  }

  function mint(address to, uint256 amount) public {
    require(hasRole(MINTER_ROLE, _msgSender()), "MockERC20: must have minter role to mint");
    _mint(to, amount);
  }
}
