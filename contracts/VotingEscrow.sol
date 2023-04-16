// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./interface/IVotingEscrow.sol";

contract VotingEscrow is IVotingEscrow, AccessControlEnumerableUpgradeable {
  int128 public constant DEPOSIT_FOR_TYPE = 0;
  int128 public constant CREATE_LOCK_TYPE = 1;
  int128 public constant INCREASE_LOCK_AMOUNT = 2;
  int128 public constant INCREASE_UNLOCK_TIME = 3;

  uint256 public constant WEEK = 7 * 86400;
  uint256 public constant MAXTIME = 365 * 86400; // 1 year
  uint256 public constant MULTIPLIER = 10 ** 18;

  string private _name;
  string private _symbol;
  uint8 private _decimals;

  address private _token;
  uint256 private _supply;

  // user address -> locked info
  mapping(address => LockedBalance) _locked;

  uint256 private _epoch;
  Point[] private _pointHistory; // epoch -> unsigned point

  mapping(address => uint256) _userPointEpoch;
  mapping(address => Point[]) private _userPointHistory; // user -> Point[user_epoch]

  mapping(uint256 => int128) private _slopeChanges; // time -> signed slope change

  modifier onlyAdmin() {
    require(
      hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
      "VotingEscrow: caller is not admin"
    );
    _;
  }

  function initialize(
    string memory name_,
    string memory symbol_,
    address token_
  ) public initializer {
    __AccessControlEnumerable_init();

    _name = name_;
    _symbol = symbol_;
    _token = token_;
    _decimals = 18;

    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  function token() public view override returns (address) {
    return _token;
  }

  function setToken(address token_) external onlyAdmin {
    _token = token_;
  }

  function name() public view override returns (string memory) {
    return _name;
  }

  /**
   * @dev Returns the symbol of the token, usually a shorter version of the
   * name.
   */
  function symbol() public view override returns (string memory) {
    return _symbol;
  }

  function decimals() public view override returns (uint8) {
    return _decimals;
  }

  // function transfer(address to, uint256 amount) public override returns (bool) {
  //   return false;
  // }

  // function transferFrom(
  //   address from,
  //   address to,
  //   uint256 amount
  // ) public override returns (bool) {
  //   return false;
  // }

  function _supplyAt(
    Point memory point,
    uint256 t
  ) internal view returns (uint256) {
    Point memory lastPoint = point;

    uint256 t_i = (lastPoint.ts / WEEK) * WEEK;
    for (uint i = 0; i < 255; i++) {
      t_i += WEEK;
      int128 d_slope = 0;
      if (t_i > t) {
        t_i = t;
      } else {
        d_slope = _slopeChanges[t_i];
      }

      lastPoint.bias -= lastPoint.slope * int128(uint128(t_i - lastPoint.ts));

      if (t_i == t) break;

      lastPoint.slope += d_slope;
      lastPoint.ts = t_i;
    }

    if (lastPoint.bias < 0) lastPoint.bias = 0;
    return uint256(int256(lastPoint.bias));
  }

  function epoch() external view returns (uint256) {
    return _epoch;
  }

  function totalSupply(uint256 t) public view override returns (uint256) {
    uint256 ts = t == 0 ? block.timestamp : t;
    if (_epoch == 0) return 0;

    return _supplyAt(_pointHistory[_epoch], ts);
  }

  function balanceOf(address account) public view override returns (uint256) {
    uint256 _ts = block.timestamp;
    uint256 _userEpoch = _userPointEpoch[account];
    if (_userEpoch == 0) return 0;

    Point memory lastPoint = _userPointHistory[account][_userEpoch];
    int128 bias = lastPoint.bias -
      (lastPoint.slope * int128(uint128(_ts - lastPoint.ts)));
    if (bias < 0) return 0;
    return uint256(int256(bias));
  }

  function get_last_user_slope(address addr) external view returns (int128) {
    uint256 uepoch = _userPointEpoch[addr];
    return _userPointHistory[addr][uepoch].slope;
  }

  function user_point_history__ts(
    address addr,
    uint256 idx
  ) external view returns (uint256) {
    return _userPointHistory[addr][idx].ts;
  }

  function locked__end(address addr) public view override returns (uint256) {
    return _locked[addr].end;
  }

  function _checkpoint(
    address addr,
    LockedBalance memory oldLocked,
    LockedBalance memory newLocked
  ) internal {
    Point memory u_old;
    Point memory u_new;

    int128 old_dslope = 0;
    int128 new_dslope = 0;
    uint256 epoch = _epoch;

    if (addr != address(0)) {
      if (oldLocked.end > block.timestamp && newLocked.amount > 0) {
        u_old.slope = oldLocked.amount / int128(uint128(MAXTIME));
        u_old.bias =
          u_old.slope *
          int128(uint128(oldLocked.end - block.timestamp));
      }
      if (newLocked.end > block.timestamp && newLocked.amount > 0) {
        u_new.slope = newLocked.amount / int128(uint128(MAXTIME));
        u_new.bias =
          u_new.slope *
          int128(uint128(newLocked.end - block.timestamp));
      }

      old_dslope = _slopeChanges[oldLocked.end];
      if (newLocked.end != 0) {
        if (newLocked.end == oldLocked.end) new_dslope = old_dslope;
        else new_dslope = _slopeChanges[newLocked.end];
      }
    }

    Point memory last_point = Point({
      bias: 0,
      slope: 0,
      ts: block.timestamp,
      blk: block.number
    });
    if (epoch > 0) last_point = _pointHistory[epoch];
    uint256 last_checkpoint = last_point.ts;

    Point memory initial_last_point = last_point;
    uint256 block_slope = 0; // dblock/dt

    if (block.timestamp > last_point.ts)
      block_slope =
        (MULTIPLIER * (block.number - last_point.blk)) /
        (block.timestamp - last_point.ts);

    uint256 t_i = (last_checkpoint / WEEK) * WEEK;
    for (uint i = 0; i < 255; i++) {
      t_i += WEEK;
      int128 d_slope = 0;
      if (t_i > block.timestamp) {
        t_i = block.timestamp;
      } else {
        d_slope = _slopeChanges[t_i];
      }

      last_point.bias -=
        last_point.slope *
        int128(uint128(t_i - last_checkpoint));
      last_point.slope += d_slope;

      if (last_point.bias < 0) {
        // This can happen
        last_point.bias = 0;
      }
      if (last_point.slope < 0) {
        last_point.slope = 0;
      }
      last_checkpoint = t_i;
      last_point.ts = t_i;
      last_point.blk =
        initial_last_point.blk +
        (block_slope * (t_i - initial_last_point.ts)) /
        MULTIPLIER;
      epoch += 1;

      if (t_i == block.timestamp) {
        last_point.blk = block.number;
        break;
      } else {
        _pointHistory[epoch] = last_point;
      }
    }
    _epoch = epoch;

    if (addr != address(0)) {
      last_point.slope += (u_new.slope - u_old.slope);
      last_point.bias += (u_new.bias - u_old.bias);
      if (last_point.slope < 0) {
        last_point.slope = 0;
      }
      if (last_point.bias < 0) {
        last_point.bias = 0;
      }
    }

    // Record the changed point into history
    _pointHistory[epoch] = last_point;
    if (addr != address(0)) {
      // Schedule the slope changes (slope is going down)
      // We subtract new_user_slope from [new_locked.end]
      // and add old_user_slope to [old_locked.end]
      if (oldLocked.end > block.timestamp) {
        // old_dslope was <something> - u_old.slope, so we cancel that
        old_dslope += u_old.slope;
        if (newLocked.end == oldLocked.end) {
          old_dslope -= u_new.slope;
        }
        _slopeChanges[oldLocked.end] = old_dslope;
      }

      if (newLocked.end > block.timestamp) {
        if (newLocked.end > oldLocked.end) {
          new_dslope -= u_new.slope; // old slope disappeared at this point
          _slopeChanges[newLocked.end] = new_dslope;
        }
      }

      // Now handle user history
      _addUserPoint(addr, u_new.bias, u_new.slope);
    }
  }

  function _addUserPoint(address user, int128 bias, int128 slope) internal {
    _userPointEpoch[user] = _userPointEpoch[user] + 1;
    _userPointHistory[user][_userPointEpoch[user]] = Point({
      bias: bias,
      slope: slope,
      ts: block.timestamp,
      blk: block.number
    });
  }

  function checkpoint() external {
    LockedBalance memory oldLocked;
    LockedBalance memory newLocked;
    _checkpoint(address(0), oldLocked, newLocked);
  }

  function _depositFor(
    address _addr,
    uint256 _value,
    uint256 unlock_time,
    LockedBalance memory locked_balance,
    int128 locktype
  ) internal {
    LockedBalance memory locked = locked_balance;
    LockedBalance memory old_locked = locked;

    uint256 supply_before = _supply;
    _supply = supply_before + _value;

    locked.amount += int128(uint128(_value));
    if (unlock_time != 0) {
      locked.end = unlock_time;
    }
    _locked[_addr] = locked;
    _checkpoint(_addr, old_locked, locked);

    if (_value > 0) {
      IERC20(_token).transferFrom(_addr, address(this), _value);
    }

    emit Deposit(_addr, _value, locked.end, locktype, block.timestamp);
    emit Supply(supply_before, supply_before + _value);
  }

  function deposit_for(address _addr, uint256 _value) external override {
    LockedBalance storage locked = _locked[_addr];
    require(_value > 0, "VotingEscrow: _value must greater than 0");
    require(locked.amount > 0, "VotingEscrow: no existing lock found");
    require(
      locked.end > block.timestamp,
      "VotingEscrow: cannot add to expired lock. Withdraw"
    );
    _depositFor(_addr, _value, 0, locked, DEPOSIT_FOR_TYPE);
  }

  function create_lock(uint256 _value, uint256 _unlock_time) external override {
    uint256 unlock_time = (_unlock_time / WEEK) * WEEK;
    LockedBalance storage locked = _locked[msg.sender];
    require(_value > 0, "VotingEscrow: Nothing is locked");
    require(locked.amount == 0, "VotingEscrow: withdraw old tokens first");
    require(
      unlock_time > block.timestamp,
      "VotingEscrow: can only lock until time in the future"
    );
    require(
      unlock_time <= block.timestamp + MAXTIME,
      "VotingEscrow: Voting lock can be 1 year max"
    );
    _depositFor(msg.sender, _value, unlock_time, locked, CREATE_LOCK_TYPE);
  }

  function increase_amount(uint256 _value) external override {
    LockedBalance memory locked = _locked[msg.sender];
    require(_value > 0, "VotingEscrow: _value must greater than 0");
    require(locked.amount > 0, "VotingEscrow: no existing lock found");
    require(
      locked.end > block.timestamp,
      "VotingEscrow: cannot add to expired lock. Withdraw"
    );
    _depositFor(msg.sender, _value, 0, locked, INCREASE_LOCK_AMOUNT);
  }

  function increase_unlock_time(uint256 _unlock_time) external override {
    uint256 unlock_time = (_unlock_time / WEEK) * WEEK;
    LockedBalance memory locked = _locked[msg.sender];
    require(locked.end > block.timestamp, "VotingEscrow: lock expired");
    require(locked.amount > 0, "VotingEscrow: nothing is locked");
    require(
      unlock_time > locked.end,
      "VotingEscrow: can only increase lock duration"
    );
    require(
      unlock_time <= block.timestamp + MAXTIME,
      "VotingEscrow: can only increase lock duration"
    );
    _depositFor(msg.sender, 0, unlock_time, locked, INCREASE_UNLOCK_TIME);
  }

  function withdraw() external override {
    LockedBalance memory locked = _locked[msg.sender];
    require(
      block.timestamp >= locked.end,
      "VotingEscrow: the lock didn't expire"
    );
    uint256 value = uint256(int256(locked.amount));

    LockedBalance memory old_locked = locked;
    locked.end = 0;
    locked.amount = 0;
    _locked[msg.sender] = locked;
    uint256 supply_before = _supply;
    _supply = supply_before - value;

    _checkpoint(msg.sender, old_locked, locked);

    IERC20(_token).transfer(msg.sender, value);

    emit Withdraw(msg.sender, value, block.timestamp);
    emit Supply(supply_before, supply_before - value);
  }
}
