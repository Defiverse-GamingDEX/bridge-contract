// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EventEmitter {
    // Define the owner of the contract
    address public owner;

    // Define a mapping to store the authorization status of each address for each identifier
    mapping(address => mapping(bytes32 => bool)) public isAuthorized;

    // Define the event that will be emitted when the function is called
    event LogArgument(address indexed sender, bytes32 indexed identifier, bytes message, uint256 value);

    // Define the event that will be emitted when an address is granted a permission
    event AuthorizationGranted(address indexed addr, bytes32 indexed identifier);

    // Define the event that will be emitted when an address has a permission revoked
    event AuthorizationRevoked(address indexed addr, bytes32 indexed identifier);

    // Define the event that will be emitted when an ownership is transferred
    event OwnershipTransferred(address indexed newOwner);

    constructor() {
        // Set the contract owner to the address that deployed the contract
        owner = msg.sender;
    }

    // Define the function that will emit the event
    function emitEvent(bytes32 identifier, bytes memory message, uint256 value) public {
        // Only allow authorized addresses to call this function
        require(isAuthorized[msg.sender][identifier], "Unauthorized address");

        // Emit the event with the message sender, identifier, and message passed into the function
        emit LogArgument(msg.sender, identifier, message, value);
    }

    // Define a function to authorize an address for a specific identifier
    function authorize(bytes32 identifier, address addr) public {
        // Only allow the owner to authorize addresses
        require(msg.sender == owner, "Only the owner can authorize addresses");

        // Set the authorization status of the address for the given identifier to true
        isAuthorized[addr][identifier] = true;

        emit AuthorizationGranted(addr, identifier);
    }

    // Define a function to remove authorization for an address for a specific identifier
    function removeAuthorization(bytes32 identifier, address addr) public {
        // Only allow the owner to remove authorization
        require(msg.sender == owner, "Only the owner can remove authorization");

        // Set the authorization status of the address for the given identifier to false
        isAuthorized[addr][identifier] = false;

        emit AuthorizationRevoked(addr, identifier);
    }

    // Define a function to transfer ownership of the contract
    function transferOwnership(address newOwner) public {
        // Only allow the owner to transfer ownership
        require(msg.sender == owner, "Only the owner can transfer ownership");

        // Transfer ownership to the new owner
        owner = newOwner;

        emit OwnershipTransferred(newOwner);
    }
}