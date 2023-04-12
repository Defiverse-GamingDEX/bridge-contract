// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./interface/IGPT4veDFV.sol";
import "./interface/IVEDFV.sol";

contract GPT4veDFV is IGPT4veDFV, AccessControlEnumerableUpgradeable {
  bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

  uint256 public SECONDS_PER_DAY = 86400;

  struct UserInfo {
    uint256 amount;
    uint256 rewardDebt;
    uint256 lockPeriod;
    uint256 startTime;
    uint256 expireTime;
  }

  address public veDFV;
  address public gpt;
  uint256 public lockPeriodPerReward;
  uint256 public minLockPeriod;

  // Info of each user that locks GPT.
  mapping(address => UserInfo) public userInfo;

  modifier onlyAdmin() {
    require(
      hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
      "GPT4veDFV: caller is not admin"
    );
    _;
  }

  function initialize(
    address gpt_,
    address veDFV_,
    uint256 lockPeriodPerReward_,
    uint256 minLockPeriod_
  ) public initializer {
    __AccessControlEnumerable_init();

    veDFV = veDFV_;
    gpt = gpt_;
    lockPeriodPerReward = lockPeriodPerReward_;
    minLockPeriod = minLockPeriod_;

    address msgSender = _msgSender();
    _setupRole(DEFAULT_ADMIN_ROLE, msgSender);
  }

  function setVeDFV(address veDFV_) external onlyAdmin {
    veDFV = veDFV_;
  }

  function setGPT(address gpt_) external onlyAdmin {
    gpt = gpt_;
  }

  /**
   *
   * @param amount_ GPT to lock
   * @param lockPeriod_ Time to lock in day
   */
  function lockGPT(uint256 amount_, uint256 lockPeriod_) external {
    require(amount_ > 0, "GPT4veDFV: amount_ must greater than 0");
    require(lockPeriod_ >= minLockPeriod, "GPT4veDFV: lockPeriod_ too small");

    UserInfo storage user = userInfo[msg.sender];
    require(user.amount == 0, "GPT4veDFV: already locked");

    uint256 reward = estimateReward(amount_, lockPeriod_);
    IERC20(gpt).transferFrom(address(msg.sender), address(this), amount_);
    IVEDFV(veDFV).mint(address(msg.sender), reward);

    user.amount = amount_;
    user.rewardDebt = reward;
    user.lockPeriod = lockPeriod_;
    user.startTime = block.timestamp;
    user.expireTime = block.timestamp + lockPeriod_ * SECONDS_PER_DAY;

    emit Locked(msg.sender, amount_, lockPeriod_);
  }

  function unlockGPT() external {
    UserInfo storage user = userInfo[msg.sender];

    require(user.amount > 0, "GPT4veDFV: haven't locked");
    require(user.expireTime <= block.timestamp, "GPT4veDFV: token is not expired to unlock");

    // Burn all veDFV of user
    uint256 veDFVBalance = IERC20(veDFV).balanceOf(msg.sender);
    IVEDFV(veDFV).burnFrom(address(msg.sender), veDFVBalance);

    // Transfer GPT to user
    uint256 amount = user.amount;
    uint256 gptBalance = IERC20(gpt).balanceOf(address(this));
    if (gptBalance < amount) {
      amount = gptBalance;
    }
    IERC20(gpt).transferFrom(address(this), address(msg.sender), amount);

    user.amount = 0;
    user.rewardDebt = 0;
    user.lockPeriod = 0;
    user.startTime = 0;
    user.expireTime = 0;

    emit Unlocked(address(msg.sender), amount);
  }

  /**
   *
   * @param amount_ GPT to lock
   * @param lockPeriod_ Time to lock in day
   */
  function estimateReward(
    uint256 amount_,
    uint256 lockPeriod_
  ) public view returns (uint256) {
    return (lockPeriod_ * amount_) / lockPeriodPerReward;
  }

  function extendGPT(uint256 amount_) external {
    //
  }

  function extendLockPeriod(uint256 lockPeriod_) external {
    //
  }
}
