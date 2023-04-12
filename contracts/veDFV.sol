// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "./interface/IVEDFV.sol";

contract veDFV is IVEDFV, AccessControlEnumerableUpgradeable, ERC20Upgradeable {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
  bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

  modifier onlyAdmin() {
    require(
      hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
      "veDFV: caller is not admin"
    );
    _;
  }

  function initialize(
    string memory name,
    string memory symbol
  ) public initializer {
    __AccessControlEnumerable_init();
    __ERC20_init(name, symbol);

    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(MINTER_ROLE, _msgSender());
    _setupRole(BURNER_ROLE, _msgSender());
    _setupRole(TRANSFER_ROLE, _msgSender());
  }

  function mint(address to, uint256 amount) public {
    require(
      hasRole(MINTER_ROLE, _msgSender()),
      "veDFV: must have minter role to mint"
    );
    _mint(to, amount);
  }

  function burn(uint256 amount) public {
    require(
      hasRole(BURNER_ROLE, _msgSender()),
      "veDFV: must have burner role to burn"
    );
    _burn(_msgSender(), amount);
  }

  function burnFrom(address account, uint256 amount) public override {
    require(
      hasRole(BURNER_ROLE, _msgSender()),
      "veDFV: must have burner role to burn"
    );
    // _spendAllowance(account, _msgSender(), amount);
    _burn(account, amount);
  }

  function transfer(address to, uint256 amount) public override returns (bool) {
    require(
      hasRole(TRANSFER_ROLE, _msgSender()),
      "veDFV: must have transfer role to transfer"
    );
    address owner = _msgSender();
    _transfer(owner, to, amount);
    return true;
  }

  function transferFrom(
    address from,
    address to,
    uint256 amount
  ) public virtual override returns (bool) {
    require(
      hasRole(TRANSFER_ROLE, _msgSender()),
      "veDFV: must have transfer role to transfer"
    );
    address spender = _msgSender();
    _spendAllowance(from, spender, amount);
    _transfer(from, to, amount);
    return true;
  }
}
