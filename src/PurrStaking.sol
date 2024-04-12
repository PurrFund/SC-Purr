// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { UserPower, PoolInfo, PoolType } from "./types/PurrStaingType.sol";
import { IPurrStaking } from "./interfaces/IPurrStaking.sol";

/**
 * @title PurrStaking
 * @notice Tier system and staking model
 */
contract PurrStaking is IPurrStaking, Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint16 public poolId;
    uint256 public timeLock;
    IERC20 public launchPadToken;

    mapping(address staker => UserPower userPower) public userPower;
    mapping(PoolType poolType => PoolInfo pool) public poolInfo;

    constructor(address _launchPadToken, address _initialOnwer) Ownable(_initialOnwer) {
        launchPadToken = IERC20(_launchPadToken);
    }

    /**
     * @notice Stake token's protocol.
     *
     * @dev Will update user's power base on user's balance.
     * @dev Emit a {Stake} event.
     *
     * Requirements:
     *   - Require sender approve amount token's staking for this contract more than {amount}.
     *
     * @param _amount The amount user will stake.
     */
    function stake(uint256 _amount, PoolType _poolType) external {
        _stake(_amount, _poolType);
    }

    /**
     * @notice Unstake token's protocol.
     *
     * @dev Will update user's power base on user's balance.
     * @dev Do not transfer {amount} to owner, lock {amount} for {timeLock} before can withdraw.
     * @dev Emit a {UnStake} event.
     *
     * Requirements:
     *   - Amount must be smaller than current balance stake.
     *
     * @param _amount The amount user will stake.
     *
     * @return status The result of staking.
     */
    function unstake(uint256 _amount, PoolType _poolType) external returns (bool) {
        bool status = _unStake(_amount, _poolType);
        return status;
    }

    // function withDraw() extenal return (bool) {
    //     _withDraw();
    // }

    function updatePool(PoolType _poolType, PoolInfo calldata pool) external onlyOwner {
        poolInfo[_poolType] = pool;
    }

    /**
     * @dev Equivalent to {stake} function.
     */
    function _stake(uint256 _amount, PoolType _poolType) internal returns (bool) {
        address sender = msg.sender;
        PoolInfo storage pool = poolInfo[_poolType];
        UserPower storage user = userPower[sender];
        uint256 currentPoint = _amount * pool.multiplier;

        if (launchPadToken.balanceOf(sender) < _amount) {
            revert InsufficientAmount(_amount);
        }

        if (currentPoint < pool.minPoint) {
            revert InvalidPoint(currentPoint);
        }

        if (_amount < 0) {
            revert InvalidAmount(_amount);
        }

        // update pool weight
        pool.totalStaked += _amount;
        ++pool.numberStaker;

        // update user powerun
        user.balance += _amount;
        user.pPoint += currentPoint;

        (PoolType tier, uint256 userWeight) = _getPower(user.pPoint);
        user.tier = tier;
        user.weight = userWeight;

        IERC20(launchPadToken).safeTransferFrom(sender, address(this), _amount);

        emit Stake(sender, _amount, block.timestamp, currentPoint, userWeight, tier);

        return true;
    }

    /**
     * @dev Equivalent to {unStake} function.
     */
    function _unStake(uint256 _amount, PoolType _poolType) internal returns (bool) {
        address sender = msg.sender;
        PoolInfo storage pool = poolInfo[_poolType];
        UserPower storage user = userPower[sender];
        uint256 currentBalance = user.balance;
        uint256 currentPoint = _amount * pool.multiplier;
        uint256 timeStake = block.timestamp - user.timeLocked;

        if (_amount > currentBalance) {
            revert ExceedBalance(_amount);
        }

        if (_amount == 0) {
            revert InvalidAmount(_amount);
        }

        if (timeStake < pool.lockPeriodInDays) {
            // later handle
        }

        pool.totalStaked -= _amount;
        if (_amount == currentBalance) {
            --pool.numberStaker;
        }

        currentBalance -= _amount;
        user.pPoint -= currentPoint;
        user.balance = currentBalance;

        (PoolType tier, uint256 userWeight) = _getPower(currentBalance);
        user.tier = tier;
        user.weight = userWeight;

        IERC20(launchPadToken).safeTransferFrom(msg.sender, address(this), _amount);

        emit UnStake(sender, _amount, block.timestamp, user.pPoint, userWeight, tier);

        return true;
    }

    /**
     * @dev Get user's power base on user's balance
     */
    function _getPower(uint256 _point) internal view returns (PoolType tier, uint256 weight) {
        if (_point < poolInfo[PoolType.BZONZE].minPoint) {
            return (PoolType.ZERO, _point);
        } else if (_point < poolInfo[PoolType.SLIVER].minPoint) {
            return (PoolType.BZONZE, _getWeight(_point, poolInfo[PoolType.BZONZE].minPoint, poolInfo[PoolType.BZONZE].minWeight));
        } else if (_point < poolInfo[PoolType.GOLD].minPoint) {
            return (PoolType.SLIVER, _getWeight(_point, poolInfo[PoolType.SLIVER].minPoint, poolInfo[PoolType.SLIVER].minWeight));
        } else if (_point < poolInfo[PoolType.DIAMOND].minPoint) {
            return (PoolType.GOLD, _getWeight(_point, poolInfo[PoolType.GOLD].minPoint, poolInfo[PoolType.GOLD].minWeight));
        } else if (_point >= poolInfo[PoolType.DIAMOND].minPoint) {
            return
                (PoolType.DIAMOND, _getWeight(_point, poolInfo[PoolType.DIAMOND].minPoint, poolInfo[PoolType.DIAMOND].minWeight));
        }
    }

    function _getWeight(uint256 _point, uint256 _mintPoint, uint256 _minWeight) internal pure returns (uint256) {
        return _point.mulDiv(_mintPoint, _minWeight, Math.Rounding.Floor);
    }

    function _beforeWithDraw() internal { }

    function _afterStaking() internal { }
}
