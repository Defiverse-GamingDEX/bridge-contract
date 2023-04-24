// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "./interface/IVotingEscrow.sol";

interface IVotingEscrow {
    function token() external view returns (address);

    function get_last_user_slope(address addr) external view returns (uint256);

    function locked__end(address addr) external view returns (uint256);
}

contract GaugeController is ReentrancyGuard, AccessControlEnumerableUpgradeable {
    // 7 * 86400 seconds - all future times are rounded by week
    uint256 constant WEEK = 604800;

    // Cannot change weight votes more often than once in 10 days
    uint256 constant WEIGHT_VOTE_DELAY = 10 * 86400;

    struct Point {
        uint256 bias;
        uint256 slope;
    }

    struct VotedSlope {
        uint256 slope;
        uint256 power;
        uint256 end;
    }

    event AddType(string name, uint256 type_id);
    event NewTypeWeight(uint256 type_id, uint256 time, uint256 weight, uint256 total_weight);
    event NewGaugeWeight(address gauge_address, uint256 time, uint256 weight, uint256 total_weight);
    event VoteForGauge(uint256 time, address user, address gauge_addr, uint256 weight);
    event NewGauge(address addr, uint256 gauge_type, uint256 weight);

    uint256 constant MULTIPLIER = 10 ** 18;

    address TOKEN; // 80-20 BAL-WETH BPT token
    address VOTING_ESCROW; // Voting escrow
    address AUTHORIZER_ADAPTOR; // Authorizer Adaptor

    // Gauge parameters
    // All numbers are "fixed point" on the basis of 1e18
    uint256 public n_gauge_types;
    uint256 public n_gauges;
    mapping(uint256 => string) public gauge_type_names;

    // Needed for enumeration
    address[1000000000] public gauges;

    // we increment values by 1 prior to storing them here so we can rely on a value
    // of zero as meaning the gauge has not been set
    mapping(address => uint256) gauge_types_;

    mapping(address => mapping(address => VotedSlope)) public vote_user_slopes; // user -> gauge_addr -> VotedSlope
    mapping(address => uint256) public vote_user_power; // Total vote power used by user
    mapping(address => mapping(address => uint256)) public last_user_vote; // Last user vote's timestamp for each gauge address

    // Past and scheduled points for gauge weight, sum of weights per type, total weight
    // Point is for bias+slope
    // changes_* are for changes in slope
    // time_* are for the last change timestamp
    // timestamps are rounded to whole weeks

    mapping(address => mapping(uint256 => Point)) public points_weight; // gauge_addr -> time -> Point
    mapping(address => mapping(uint256 => uint256)) changes_weight; // gauge_addr -> time -> slope
    mapping(address => uint256) public time_weight; // gauge_addr -> last scheduled time (next week)

    mapping(uint256 => mapping(uint256 => Point)) public points_sum; // type_id -> time -> Point
    mapping(uint256 => mapping(uint256 => uint256)) changes_sum; // type_id -> time -> slope
    uint256[1000000000] public time_sum; // type_id -> last scheduled time (next week)

    mapping(uint256 => uint256) public points_total; // time -> total weight
    uint256 public time_total; // last scheduled time

    mapping(uint256 => mapping(uint256 => uint256)) public points_type_weight; // type_id -> time -> type weight
    uint256[1000000000] public time_type_weight; // type_id -> last scheduled time (next week)

    function initialize(address _voting_escrow, address _authorizer_adaptor) public initializer {
        __AccessControlEnumerable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        require(_voting_escrow != address(0), "Invalid address for voting escrow");
        require(_authorizer_adaptor != address(0), "Invalid address for authorizer adaptor");

        TOKEN = IVotingEscrow(_voting_escrow).token();
        VOTING_ESCROW = _voting_escrow;
        AUTHORIZER_ADAPTOR = _authorizer_adaptor;
        time_total = (block.timestamp / WEEK) * WEEK;
    }

    function token() external view returns (address) {
        return TOKEN;
    }

    function voting_escrow() external view returns (address) {
        return VOTING_ESCROW;
    }

    function admin() external view returns (address) {
        return AUTHORIZER_ADAPTOR;
    }

    function gauge_exists(address _addr) public view returns (bool) {
        uint256 gauge_type = gauge_types_[_addr];
        return gauge_type > 0;
    }

    function gauge_types(address _addr) public view returns (uint256) {
        uint256 gauge_type = gauge_types_[_addr];
        require(gauge_type != 0, "GaugeController: gauge type not found");
        return gauge_type - 1;
    }

    function _get_type_weight(uint256 gauge_type) internal returns (uint256) {
        uint256 t = time_type_weight[uint256(gauge_type)];
        if (t > 0) {
            uint256 w = points_type_weight[gauge_type][t];
            for (uint256 i = 0; i < 500; i++) {
                if (t > block.timestamp) {
                    break;
                }
                t += WEEK;
                points_type_weight[gauge_type][t] = w;
                if (t > block.timestamp) {
                    time_type_weight[uint256(gauge_type)] = t;
                }
            }
            return w;
        } else {
            return 0;
        }
    }

    function _get_sum(uint256 gauge_type) internal returns (uint256) {
        uint256 t = time_sum[uint256(gauge_type)];
        if (t > 0) {
            Point memory pt = points_sum[gauge_type][t];
            for (uint256 i = 0; i < 500; i++) {
                if (t > block.timestamp) {
                    break;
                }
                t += WEEK;
                uint256 d_bias = pt.slope * WEEK;
                if (pt.bias > d_bias) {
                    pt.bias -= d_bias;
                    uint256 d_slope = changes_sum[gauge_type][t];
                    pt.slope -= d_slope;
                } else {
                    pt.bias = 0;
                    pt.slope = 0;
                }
                points_sum[gauge_type][t] = pt;
                if (t > block.timestamp) {
                    time_sum[uint256(gauge_type)] = t;
                }
            }
            return pt.bias;
        } else {
            return 0;
        }
    }

    function _get_total() internal returns (uint256) {
        uint256 t = time_total;
        uint256 _n_gauge_types = n_gauge_types;
        if (t > block.timestamp) {
            // If we have already checkpointed - still need to change the value
            t -= WEEK;
        }
        uint256 pt = points_total[t];

        for (uint256 gauge_type = 0; gauge_type < 100; gauge_type++) {
            if (uint256(gauge_type) == _n_gauge_types) {
                break;
            }
            _get_sum(gauge_type);
            _get_type_weight(gauge_type);
        }

        for (uint256 i = 0; i < 500; i++) {
            if (t > block.timestamp) {
                break;
            }
            t += WEEK;
            pt = 0;
            // Scales as n_types * n_unchecked_weeks (hopefully 1 at most)
            for (uint256 gauge_type = 0; gauge_type < 100; gauge_type++) {
                if (uint256(gauge_type) == _n_gauge_types) {
                    break;
                }
                uint256 type_sum = points_sum[gauge_type][t].bias;
                uint256 type_weight = points_type_weight[gauge_type][t];
                pt += type_sum * type_weight;
            }
            points_total[t] = pt;

            if (t > block.timestamp) {
                time_total = t;
            }
        }
        return pt;
    }

    function _get_weight(address gauge_addr) internal returns (uint256) {
        uint256 t = time_weight[gauge_addr];
        if (t > 0) {
            Point storage pt = points_weight[gauge_addr][t];
            for (uint256 i = 0; i < 500; i++) {
                if (t > block.timestamp) {
                    break;
                }
                t += WEEK;
                uint256 d_bias = pt.slope * WEEK;
                if (pt.bias > d_bias) {
                    pt.bias -= d_bias;
                    uint256 d_slope = changes_weight[gauge_addr][t];
                    pt.slope -= d_slope;
                } else {
                    pt.bias = 0;
                    pt.slope = 0;
                }
                points_weight[gauge_addr][t] = pt;
                if (t > block.timestamp) {
                    time_weight[gauge_addr] = t;
                }
            }
            return pt.bias;
        } else {
            return 0;
        }
    }

    function add_gauge(address addr, uint256 gauge_type, uint256 weight) external {
        require(msg.sender == AUTHORIZER_ADAPTOR, "Not authorized");
        require(gauge_type >= 0 && gauge_type < n_gauge_types, "Invalid gauge type");
        require(gauge_types_[addr] == 0, "Gauge already exists");

        n_gauges++;
        gauges[uint256(n_gauges) - 1] = addr;
        gauge_types_[addr] = gauge_type + 1;
        uint256 next_time = ((block.timestamp + WEEK) / WEEK) * WEEK;

        if (weight > 0) {
            uint256 type_weight = _get_type_weight(gauge_type);
            uint256 old_sum = _get_sum(gauge_type);
            uint256 old_total = _get_total();

            points_sum[gauge_type][next_time].bias = weight + old_sum;
            time_sum[uint256(gauge_type)] = next_time;
            points_total[next_time] = old_total + type_weight * weight;
            time_total = next_time;

            points_weight[addr][next_time].bias = weight;
        }

        if (time_sum[uint256(gauge_type)] == 0) {
            time_sum[uint256(gauge_type)] = next_time;
        }
        time_weight[addr] = next_time;

        emit NewGauge(addr, gauge_type, weight);
    }

    function checkpoint() external {
        _get_total();
    }

    function checkpoint_gauge(address addr) external {
        _get_weight(addr);
        _get_total();
    }

    function _gauge_relative_weight(address addr, uint256 time) internal view returns (uint256) {
        uint256 t = (time / WEEK) * WEEK;
        uint256 _total_weight = points_total[t];

        if (_total_weight > 0) {
            uint256 gauge_type = gauge_types_[addr] - 1;
            uint256 _type_weight = points_type_weight[gauge_type][t];
            uint256 _gauge_weight = points_weight[addr][t].bias;
            return (MULTIPLIER * _type_weight * _gauge_weight) / _total_weight;
        } else {
            return 0;
        }
    }

    function gauge_relative_weight(address addr, uint256 time) external view returns (uint256) {
        if (time == 0) {
            time = block.timestamp;
        }
        return _gauge_relative_weight(addr, time);
    }

    function gauge_relative_weight_write(address addr, uint256 time) external returns (uint256) {
        _get_weight(addr);
        _get_total();
        return _gauge_relative_weight(addr, time);
    }

    function _change_type_weight(uint256 type_id, uint256 weight) internal {
        uint256 old_weight = _get_type_weight(type_id);
        uint256 old_sum = _get_sum(type_id);
        uint256 total_weight = _get_total();
        uint256 next_time = ((block.timestamp + WEEK) / WEEK) * WEEK;

        total_weight = total_weight + old_sum * weight - old_sum * old_weight;
        points_total[next_time] = total_weight;
        points_type_weight[type_id][next_time] = weight;
        time_total = next_time;
        time_type_weight[uint256(type_id)] = next_time;

        emit NewTypeWeight(type_id, next_time, weight, total_weight);
    }

    function add_type(string memory _name, uint256 weight) external {
        require(msg.sender == AUTHORIZER_ADAPTOR, "Only authorized adapter can add a new gauge type.");
        uint256 type_id = n_gauge_types;
        gauge_type_names[type_id] = _name;
        n_gauge_types = type_id + 1;
        if (weight != 0) {
            _change_type_weight(type_id, weight);
            emit AddType(_name, type_id);
        }
    }

    function change_type_weight(uint256 type_id, uint256 weight) external {
        require(msg.sender == AUTHORIZER_ADAPTOR, "Only authorized adapter can change gauge type weight.");
        _change_type_weight(type_id, weight);
    }

    function _change_gauge_weight(address addr, uint256 weight) internal {
        // Change gauge weight
        // Only needed when testing in reality
        uint256 gauge_type = gauge_types_[addr] - 1;
        uint256 old_gauge_weight = _get_weight(addr);
        uint256 type_weight = _get_type_weight(gauge_type);
        uint256 old_sum = _get_sum(gauge_type);
        uint256 _total_weight = _get_total();
        uint256 next_time = ((block.timestamp + WEEK) / WEEK) * WEEK;

        points_weight[addr][next_time].bias = weight;
        time_weight[addr] = next_time;

        uint256 new_sum = old_sum + weight - old_gauge_weight;
        points_sum[gauge_type][next_time].bias = new_sum;
        time_sum[uint256(gauge_type)] = next_time;

        _total_weight = _total_weight + new_sum * type_weight - old_sum * type_weight;
        points_total[next_time] = _total_weight;
        time_total = next_time;

        emit NewGaugeWeight(addr, block.timestamp, weight, _total_weight);
    }

    function change_gauge_weight(address addr, uint256 weight) external {
        require(msg.sender == AUTHORIZER_ADAPTOR, "Unauthorized");
        _change_gauge_weight(addr, weight);
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    // function _vote_for_gauge_weights(address _user, address _gauge_addr, uint256 _user_weight) internal {
    //     uint256 slope = uint256(IVotingEscrow(VOTING_ESCROW).get_last_user_slope(_user));
    //     uint256 lock_end = IVotingEscrow(VOTING_ESCROW).locked__end(_user);
    //     uint256 next_time = ((block.timestamp + WEEK) / WEEK) * WEEK;

    //     require(lock_end > next_time, "Your token lock expires too soon");
    //     require(_user_weight >= 0 && _user_weight <= 10000, "You used all your voting power");
    //     require(block.timestamp >= last_user_vote[_user][_gauge_addr] + WEIGHT_VOTE_DELAY, "Cannot vote so often");

    //     uint256 gauge_type = gauge_types_[_gauge_addr] - 1;
    //     require(gauge_type >= 0, "Gauge not added");

    //     // Prepare slopes and biases in memory
    //     (VotedSlope memory old_slope, uint256 old_bias, uint256 old_dt) = _prepare_slopes_and_biases(
    //         _user,
    //         _gauge_addr,
    //         next_time
    //     );
    //     (VotedSlope memory new_slope, uint256 new_bias, uint256 new_dt) = _prepare_new_slope_and_bias(
    //         slope,
    //         lock_end,
    //         _user_weight,
    //         next_time
    //     );

    //     // // Check and update powers (weights) used
    //     // uint256 power_used = _check_and_update_powers_used(_user, old_slope, new_slope);

    //     // // Remove old and schedule new slope changes
    //     // (
    //     //     uint256 old_weight_bias,
    //     //     uint256 old_weight_slope,
    //     //     uint256 old_sum_bias,
    //     //     uint256 old_sum_slope
    //     // ) = _get_old_weights_and_slopes(_gauge_addr, gauge_type, next_time);
    //     // (
    //     //     uint256 new_weight_bias,
    //     //     uint256 new_weight_slope,
    //     //     uint256 new_sum_bias,
    //     //     uint256 new_sum_slope
    //     // ) = _get_new_weights_and_slopes(
    //     //         old_weight_bias,
    //     //         old_weight_slope,
    //     //         old_sum_bias,
    //     //         old_sum_slope,
    //     //         old_bias,
    //     //         new_bias,
    //     //         old_slope,
    //     //         new_slope,
    //     //         next_time
    //     //     );
    //     // _update_weights_and_slopes(
    //     //     _gauge_addr,
    //     //     gauge_type,
    //     //     next_time,
    //     //     old_slope,
    //     //     new_slope,
    //     //     old_weight_bias,
    //     //     new_weight_bias,
    //     //     old_weight_slope,
    //     //     new_weight_slope,
    //     //     old_sum_bias,
    //     //     new_sum_bias,
    //     //     old_sum_slope,
    //     //     new_sum_slope
    //     // );
    //     // _cancel_old_slope_changes(_gauge_addr, gauge_type, old_slope);
    //     // _add_new_slope_changes(_gauge_addr, gauge_type, new_slope);
    //     // _get_total();

    //     // // Record last action time
    //     // last_user_vote[_user][_gauge_addr] = block.timestamp;

    //     // emit VoteForGauge(block.timestamp, _user, _gauge_addr, _user_weight);

    //     // Check and update powers (weights) used
    //     uint256 power_used = _check_and_update_powers_used(_user, old_slope, new_slope);

    //     // Remove old and schedule new slope changes
    //     uint256 old_weight_bias = _get_weight(_gauge_addr);
    //     uint256 old_weight_slope = points_weight[_gauge_addr][next_time].slope;
    //     uint256 old_sum_bias = _get_sum(gauge_type);
    //     uint256 old_sum_slope = points_sum[gauge_type][next_time].slope;

    //     points_weight[_gauge_addr][next_time].bias = max(old_weight_bias + new_bias, old_bias) - old_bias;
    //     points_sum[gauge_type][next_time].bias = max(old_sum_bias + new_bias, old_bias) - old_bias;

    //     if (old_slope.end > next_time) {
    //         points_weight[_gauge_addr][next_time].slope =
    //             max(old_weight_slope + new_slope.slope, old_slope.slope) -
    //             old_slope.slope;
    //         points_sum[gauge_type][next_time].slope =
    //             max(old_sum_slope + new_slope.slope, old_slope.slope) -
    //             old_slope.slope;
    //     } else {
    //         points_weight[_gauge_addr][next_time].slope += new_slope.slope;
    //         points_sum[gauge_type][next_time].slope += new_slope.slope;
    //     }

    //     if (old_slope.end > block.timestamp) {
    //         // Cancel old slope changes if they still didn't happen
    //         changes_weight[_gauge_addr][old_slope.end] -= old_slope.slope;
    //         changes_sum[gauge_type][old_slope.end] -= old_slope.slope;
    //     }

    //     // Add slope changes for new slopes
    //     changes_weight[_gauge_addr][new_slope.end] += new_slope.slope;
    //     changes_sum[gauge_type][new_slope.end] += new_slope.slope;

    //     _get_total();

    //     vote_user_slopes[_user][_gauge_addr] = new_slope;

    //     // Record last action time
    //     last_user_vote[_user][_gauge_addr] = block.timestamp;

    //     emit VoteForGauge(block.timestamp, _user, _gauge_addr, _user_weight);
    // }

    // function _prepare_slopes_and_biases(
    //     address _user,
    //     address _gauge_addr,
    //     uint256 _next_time
    // ) internal view returns (VotedSlope memory, uint256, uint256) {
    //     VotedSlope memory old_slope = vote_user_slopes[_user][_gauge_addr];
    //     uint256 old_dt = 0;

    //     if (old_slope.end > _next_time) {
    //         old_dt = old_slope.end - _next_time;
    //     }

    //     uint256 old_bias = old_slope.slope * old_dt;
    //     return (old_slope, old_bias, old_dt);
    // }

    // function _prepare_new_slope_and_bias(
    //     uint256 slope,
    //     uint256 lock_end,
    //     uint256 user_weight,
    //     uint256 next_time
    // ) internal pure returns (VotedSlope memory, uint256, uint256) {
    //     uint256 old_dt = 0;
    //     uint256 new_dt = lock_end - next_time;

    //     VotedSlope memory old_slope = VotedSlope(0, 0, 0); // Initialize an empty VotedSlope struct

    //     // If the user already has a slope for this gauge, calculate its old bias and duration
    //     if (old_slope.end > next_time) {
    //         old_dt = old_slope.end - next_time;
    //         uint256 old_bias = old_slope.slope * old_dt;
    //     }

    //     // Calculate the new slope and bias based on the user's weight
    //     VotedSlope memory new_slope = VotedSlope({
    //         slope: (slope * user_weight) / 10000,
    //         end: lock_end,
    //         power: user_weight
    //     });

    //     uint256 new_bias = new_slope.slope * new_dt;

    //     return (new_slope, new_bias, new_dt);
    // }

    function _check_and_update_powers_used(
        address _user,
        VotedSlope memory old_slope,
        VotedSlope memory new_slope
    ) internal returns (uint256) {
        uint256 power_used = vote_user_power[_user];
        power_used = power_used + new_slope.power - old_slope.power;
        vote_user_power[_user] = power_used;

        require(power_used >= 0 && power_used <= 10000, "Used too much power");

        return power_used;
    }

    // stack too deep
    function _vote_for_gauge_weights(address _user, address _gauge_addr, uint256 _user_weight) internal {
        uint256 slope = uint256(IVotingEscrow(VOTING_ESCROW).get_last_user_slope(_user));
        uint256 lock_end = IVotingEscrow(VOTING_ESCROW).locked__end(_user);
        uint256 next_time = ((block.timestamp + WEEK) / WEEK) * WEEK;

        require(lock_end > next_time, "Your token lock expires too soon");
        require(_user_weight >= 0 && _user_weight <= 10000, "You used all your voting power");
        require(block.timestamp >= last_user_vote[_user][_gauge_addr] + WEIGHT_VOTE_DELAY, "Cannot vote so often");

        uint256 gauge_type = gauge_types_[_gauge_addr] - 1;
        require(gauge_type >= 0, "Gauge not added");

        // Prepare slopes and biases in memory
        VotedSlope memory old_slope = vote_user_slopes[_user][_gauge_addr];
        uint256 old_dt = 0;

        if (old_slope.end > next_time) {
            old_dt = old_slope.end - next_time;
        }

        uint256 old_bias = old_slope.slope * old_dt;

        VotedSlope memory new_slope = VotedSlope({
            slope: (slope * _user_weight) / 10000,
            end: lock_end,
            power: _user_weight
        });

        // uint256 new_dt = lock_end - next_time; // dev: raises when expired
        uint256 new_bias = new_slope.slope * (lock_end - next_time);

        // Check and update powers (weights) used
        _check_and_update_powers_used(_user, old_slope, new_slope);

        // Remove old and schedule new slope changes
        // uint256 old_weight_bias = _get_weight(_gauge_addr);
        // uint256 old_weight_slope = points_weight[_gauge_addr][next_time].slope;
        // uint256 old_sum_bias = _get_sum(gauge_type);
        // uint256 old_sum_slope = points_sum[gauge_type][next_time].slope;

        points_weight[_gauge_addr][next_time].bias = max(_get_weight(_gauge_addr) + new_bias, old_bias) - old_bias;
        points_sum[gauge_type][next_time].bias = max(_get_sum(gauge_type) + new_bias, old_bias) - old_bias;

        if (old_slope.end > next_time) {
            points_weight[_gauge_addr][next_time].slope =
                max(points_weight[_gauge_addr][next_time].slope + new_slope.slope, old_slope.slope) -
                old_slope.slope;
            points_sum[gauge_type][next_time].slope =
                max(points_sum[gauge_type][next_time].slope + new_slope.slope, old_slope.slope) -
                old_slope.slope;
        } else {
            points_weight[_gauge_addr][next_time].slope += new_slope.slope;
            points_sum[gauge_type][next_time].slope += new_slope.slope;
        }

        if (old_slope.end > block.timestamp) {
            // Cancel old slope changes if they still didn't happen
            changes_weight[_gauge_addr][old_slope.end] -= old_slope.slope;
            changes_sum[gauge_type][old_slope.end] -= old_slope.slope;
        }

        // Add slope changes for new slopes
        changes_weight[_gauge_addr][new_slope.end] += new_slope.slope;
        changes_sum[gauge_type][new_slope.end] += new_slope.slope;

        _get_total();

        vote_user_slopes[_user][_gauge_addr] = new_slope;

        // Record last action time
        last_user_vote[_user][_gauge_addr] = block.timestamp;

        emit VoteForGauge(block.timestamp, _user, _gauge_addr, _user_weight);
    }

    function vote_for_many_gauge_weights(
        address[8] memory _gauge_addrs,
        uint256[8] memory _user_weight
    ) external nonReentrant {
        for (uint256 i = 0; i < 8; i++) {
            if (_gauge_addrs[i] == address(0)) {
                break;
            }
            _vote_for_gauge_weights(msg.sender, _gauge_addrs[i], _user_weight[i]);
        }
    }

    function vote_for_gauge_weights(address _gauge_addr, uint256 _user_weight) external {
        _vote_for_gauge_weights(msg.sender, _gauge_addr, _user_weight);
    }

    function get_gauge_weight(address addr) external view returns (uint256) {
        return points_weight[addr][time_weight[addr]].bias;
    }

    function get_type_weight(uint256 type_id) external view returns (uint256) {
        return points_type_weight[type_id][time_type_weight[uint256(type_id)]];
    }

    function get_total_weight() external view returns (uint256) {
        return points_total[time_total];
    }

    function get_weights_sum_per_type(uint256 type_id) external view returns (uint256) {
        return points_sum[type_id][time_sum[uint256(type_id)]].bias;
    }
}
