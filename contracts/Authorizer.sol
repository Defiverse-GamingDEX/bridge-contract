// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";

contract Authorizer is AccessControlEnumerableUpgradeable {
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    address public admin;

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Authorizer: caller is not admin"
        );
        _;
    }

    modifier onlyOperator() {
        require(
            hasRole(OPERATOR_ROLE, _msgSender()),
            "Authorizer: caller is not operator"
        );
        _;
    }

    function initialize(address admin_) public initializer {
        __AccessControlEnumerable_init();

        admin = admin_;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(OPERATOR_ROLE, _msgSender());
    }

    function canPerform(
        bytes32 actionId,
        address account,
        address where
    ) external view returns (bool) {
        return true;
    }
}
