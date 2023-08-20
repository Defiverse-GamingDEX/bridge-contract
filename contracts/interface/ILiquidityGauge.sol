// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

interface ILiquidityGauge {
  /**
   * @notice Returns BAL liquidity emissions calculated during checkpoints for the given user.
   * @param user User address.
   * @return uint256 BAL amount to issue for the address.
   */
  function integrate_fraction(address user) external view returns (uint256);

  /**
   * @notice Record a checkpoint for a given user.
   * @param user User address.
   * @return bool Always true.
   */
  function user_checkpoint(address user) external returns (bool);

  /**
   * @notice Returns true if gauge is killed; false otherwise.
   */
  function is_killed() external view returns (bool);

  /**
   * @notice Kills the gauge so it cannot mint BAL.
   */
  function killGauge() external;

  /**
   * @notice Unkills the gauge so it can mint BAL again.
   */
  function unkillGauge() external;

  /**
   * @notice Sets a new relative weight cap for the gauge.
   * The value shall be normalized to 1e18, and not greater than MAX_RELATIVE_WEIGHT_CAP.
   * @param relativeWeightCap New relative weight cap.
   */
  function setRelativeWeightCap(uint256 relativeWeightCap) external;

  /**
   * @notice Gets the relative weight cap for the gauge.
   */
  function getRelativeWeightCap() external view returns (uint256);

  /**
   * @notice Returns the gauge's relative weight for a given time, capped to its relative weight cap attribute.
   * @param time Timestamp in the past or present.
   */
  function getCappedRelativeWeight(
    uint256 time
  ) external view returns (uint256);

  function add_reward(address _reward_token, address _distributor) external;

  function set_reward_distributor(address _reward_token, address _distributor) external;
}
