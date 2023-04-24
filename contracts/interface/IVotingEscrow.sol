// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVotingEscrow {
  struct Point {
    int128 bias;
    int128 slope; // - dweight / dt
    uint256 ts;
    uint256 blk; // block
  }

  struct LockedBalance {
    int128 amount;
    uint256 end;
  }

  event Deposit(
    address indexed provider,
    uint256 value,
    uint256 locktime,
    int128 locktype,
    uint256 ts
  );

  event Withdraw(address indexed provider, uint256 value, uint256 ts);

  event Supply(uint256 prevSupply, uint256 supply);

  function token() external view returns (address);

  function name() external view returns (string memory);

  function symbol() external view returns (string memory);

  function decimals() external view returns (uint8);

  function totalSupply() external view returns (uint256);

  function balanceOf(address account) external view returns (uint256);

  // function transfer(address to, uint256 amount) external returns (bool);

  // function transferFrom(
  //   address from,
  //   address to,
  //   uint256 amount
  // ) external returns (bool);

  function get_last_user_slope(address addr) external view returns (int128);

  function user_point_history__ts(
    address addr,
    uint256 idx
  ) external view returns (uint256);

  function locked__end(address addr) external view returns (uint256);

  function deposit_for(address _addr, uint256 _value) external;

  function create_lock(uint256 _value, uint256 _unlock_time) external;

  function increase_amount(uint256 _value) external;

  function increase_unlock_time(uint256 _unlock_time) external;

  function withdraw() external;
}
