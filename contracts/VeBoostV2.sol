// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./interface/IVotingEscrow.sol";

// interface BoostV1 {
//     function ownerOf(uint256 _token_id) external view returns (address);

//     function token_boost(uint256 _token_id) external view returns (int256);

//     function token_expiry(uint256 _token_id) external view returns (uint256);
// }

interface ERC1271 {
    function isValidSignature(bytes32 _hash, bytes calldata _signature) external view returns (bytes32);
}

contract VeBoostV2 {
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Boost(address indexed _from, address indexed _to, uint256 _bias, uint256 _slope, uint256 _start);
    event Migrate(uint256 indexed _token_id);

    struct Point {
        uint256 bias;
        uint256 slope;
        uint256 ts;
    }

    uint256 constant MAX_UINT256 = 2 ** 256 - 1;
    string public constant NAME = "Vote-Escrowed Boost";
    string public constant SYMBOL = "veBoost";
    string public constant VERSION = "v2.0.0";

    bytes32 public constant EIP712_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant ERC1271_MAGIC_VAL = 0x1626ba7e00000000000000000000000000000000000000000000000000000000;

    uint256 public constant WEEK = 86400 * 7;

    address public immutable BOOST_V1;
    address public immutable VE;
    bytes32 public immutable DOMAIN_SEPARATOR;

    mapping(address => mapping(address => uint256)) public allowance;
    mapping(address => uint256) public nonces;

    mapping(address => Point) public delegated;
    mapping(address => mapping(uint256 => uint256)) public delegated_slope_changes;

    mapping(address => Point) public received;
    mapping(address => mapping(uint256 => uint256)) public received_slope_changes;

    mapping(uint256 => bool) public migrated;

    constructor(address _boost_v1, address _ve) {
        BOOST_V1 = _boost_v1;
        uint256 id;
        assembly {
            id := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(EIP712_TYPEHASH, keccak256(bytes(NAME)), keccak256(bytes(VERSION)), id, address(this))
        );
        VE = _ve;

        emit Transfer(address(0), msg.sender, 0);
    }

    function _checkpoint_read(address _user, bool _delegated) internal view returns (Point memory) {
        Point memory point;

        if (_delegated) {
            point = delegated[_user];
        } else {
            point = received[_user];
        }

        if (point.ts == 0) {
            point.ts = block.timestamp;
        }

        if (point.ts == block.timestamp) {
            return point;
        }

        uint256 ts = (point.ts / 1 weeks) * 1 weeks;
        for (uint256 i = 0; i < 255; i++) {
            ts += 1 weeks;

            uint256 dslope = 0;
            if (block.timestamp < ts) {
                ts = block.timestamp;
            } else {
                if (_delegated) {
                    dslope = delegated_slope_changes[_user][ts];
                } else {
                    dslope = received_slope_changes[_user][ts];
                }
            }

            point.bias -= point.slope * (ts - point.ts);
            point.slope -= dslope;
            point.ts = ts;

            if (ts == block.timestamp) {
                break;
            }
        }

        return point;
    }

    function _checkpoint_write(address _user, bool _delegated) internal returns (Point memory) {
        Point memory point;

        if (_delegated) {
            point = delegated[_user];
        } else {
            point = received[_user];
        }

        if (point.ts == 0) {
            point.ts = block.timestamp;
        }

        if (point.ts == block.timestamp) {
            return point;
        }

        uint256 dbias = 0;
        uint256 ts = (point.ts / 1 weeks) * 1 weeks;
        for (uint256 i = 0; i < 255; i++) {
            ts += 1 weeks;

            uint256 dslope = 0;
            if (block.timestamp < ts) {
                ts = block.timestamp;
            } else {
                if (_delegated) {
                    dslope = delegated_slope_changes[_user][ts];
                } else {
                    dslope = received_slope_changes[_user][ts];
                }
            }

            uint256 amount = point.slope * (ts - point.ts);

            dbias += amount;
            point.bias -= amount;
            point.slope -= dslope;
            point.ts = ts;

            if (ts == block.timestamp) {
                break;
            }
        }

        if (!_delegated && dbias != 0) {
            emit Transfer(_user, address(0), dbias);
        }

        return point;
    }

    function _balance_of(address _user) internal view returns (uint256) {
        uint256 amount = IVotingEscrow(VE).balanceOf(_user);

        Point memory point = _checkpoint_read(_user, true);
        amount -= (point.bias - point.slope * (block.timestamp - point.ts));

        point = _checkpoint_read(_user, false);
        amount += (point.bias - point.slope * (block.timestamp - point.ts));

        return amount;
    }

    function _boost(address _from, address _to, uint256 _amount, uint256 _endtime) internal {
        require(_to != _from && _to != address(0), "Invalid _to address");
        require(_amount != 0, "Invalid _amount");
        require(_endtime > block.timestamp, "Invalid _endtime");
        require(_endtime % WEEK == 0, "Invalid _endtime - not multiple of WEEK");
        require(_endtime <= IVotingEscrow(VE).locked__end(_from), "IVotingEscrow: Unlock time must be in the future");

        // checkpoint delegated point
        Point memory point = _checkpoint_write(_from, true);
        require(
            _amount <= IVotingEscrow(VE).balanceOf(_from) - (point.bias - point.slope * (block.timestamp - point.ts)),
            "Insufficient balance"
        );

        // calculate slope and bias being added
        uint256 slope = _amount / (_endtime - block.timestamp);
        uint256 bias = slope * (_endtime - block.timestamp);

        // update delegated point
        point.bias += bias;
        point.slope += slope;

        // store updated values
        delegated[_from] = point;
        delegated_slope_changes[_from][_endtime] += slope;

        // update received amount
        point = _checkpoint_write(_to, false);
        point.bias += bias;
        point.slope += slope;

        // store updated values
        received[_to] = point;
        received_slope_changes[_to][_endtime] += slope;

        emit Transfer(_from, _to, _amount);
        emit Boost(_from, _to, bias, slope, block.timestamp);

        // also checkpoint received and delegated
        received[_from] = _checkpoint_write(_from, false);
        delegated[_to] = _checkpoint_write(_to, true);
    }

    function boost(address _to, uint256 _amount, uint256 _endtime, address _from) external {
        // reduce approval if necessary
        if (_from != msg.sender) {
            uint256 _allowance = allowance[_from][msg.sender];
            if (_allowance != MAX_UINT256) {
                allowance[_from][msg.sender] = _allowance - _amount;
                emit Approval(_from, msg.sender, _allowance - _amount);
            }
        }

        // call internal function to perform boost
        _boost(_from, _to, _amount, _endtime);
    }

    // function _migrate(uint256 _token_id) internal {
    //     require(!migrated[_token_id], "Token already migrated");

    //     address _from = address(uint256(_token_id) >> 96); // from
    //     address _to = BoostV1(BOOST_V1).ownerOf(_token_id); // to
    //     uint256 _amount = uint256(BoostV1(BOOST_V1).token_boost(_token_id)); // amount
    //     uint256 _expiry = BoostV1(BOOST_V1).token_expiry(_token_id); // expiry

    //     _boost(_from, _to, _amount, _expiry);

    //     migrated[_token_id] = true;
    //     emit Migrate(_token_id);
    // }

    // function migrate(uint256 _token_id) external {
    //     _migrate(_token_id);
    // }

    // function migrate_many(uint256[16] memory _token_ids) external {
    //     for (uint256 i = 0; i < 16; i++) {
    //         if (_token_ids[i] == 0) {
    //             break;
    //         }
    //         _migrate(_token_ids[i]);
    //     }
    // }

    function checkpoint_user(address _user) external {
        delegated[_user] = _checkpoint_write(_user, true);
        received[_user] = _checkpoint_write(_user, false);
    }

    function approve(address _spender, uint256 _value) public returns (bool) {
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function isContract(address _addr) internal view returns (bool) {
        uint32 size;
        assembly {
            size := extcodesize(_addr)
        }
        return (size > 0);
    }

    function permit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (bool) {
        require(block.timestamp <= _deadline, "EXPIRED_SIGNATURE");

        uint256 nonce = nonces[_owner];
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(abi.encode(PERMIT_TYPEHASH, _owner, _spender, _value, nonce, _deadline))
            )
        );

        if (isContract(_owner)) {
            bytes memory sig = abi.encode(_r, _s, bytes1(_v));
            // reentrancy not a concern since this is a staticcall
            require(ERC1271(_owner).isValidSignature(digest, sig) == ERC1271_MAGIC_VAL, "INVALID_SIGNATURE");
        } else {
            require(ecrecover(digest, _v, _r, _s) == _owner && _owner != address(0), "INVALID_SIGNATURE");
        }

        allowance[_owner][_spender] = _value;
        nonces[_owner] = nonce + 1;

        emit Approval(_owner, _spender, _value);
        return true;
    }

    function increaseAllowance(address _spender, uint256 _added_value) external returns (bool) {
        uint256 newAllowance = allowance[msg.sender][_spender] + _added_value;
        allowance[msg.sender][_spender] = newAllowance;
        emit Approval(msg.sender, _spender, newAllowance);
        return true;
    }

    function decreaseAllowance(address _spender, uint256 _subtracted_value) external returns (bool) {
        uint256 currentAllowance = allowance[msg.sender][_spender];
        require(currentAllowance >= _subtracted_value, "Decreased allowance below zero");
        uint256 newAllowance = currentAllowance - _subtracted_value;
        allowance[msg.sender][_spender] = newAllowance;
        emit Approval(msg.sender, _spender, newAllowance);
        return true;
    }

    function balanceOf(address _user) external view returns (uint256) {
        return _balance_of(_user);
    }

    function adjusted_balance_of(address _user) external view returns (uint256) {
        return _balance_of(_user);
    }

    function totalSupply() external view returns (uint256) {
        return IVotingEscrow(VE).totalSupply();
    }

    function delegated_balance(address _user) external view returns (uint256) {
        Point memory point = _checkpoint_read(_user, true);
        return point.bias - point.slope * (block.timestamp - point.ts);
    }

    function received_balance(address _user) external view returns (uint256) {
        Point memory point = _checkpoint_read(_user, false);
        return point.bias - point.slope * (block.timestamp - point.ts);
    }

    function delegable_balance(address _user) external view returns (uint256) {
        Point memory point = _checkpoint_read(_user, true);
        return IVotingEscrow(VE).balanceOf(_user) - (point.bias - point.slope * (block.timestamp - point.ts));
    }

    function name() public pure returns (string memory) {
        return NAME;
    }

    function symbol() public pure returns (string memory) {
        return SYMBOL;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function version() public pure returns (string memory) {
        return VERSION;
    }
}
