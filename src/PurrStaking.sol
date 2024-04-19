// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol"; 

import { UserPoolInfo, PoolInfo, PoolType } from "./types/PurrStaingType.sol";
import { IPurrStaking } from "./interfaces/IPurrStaking.sol";

/**
 * @title PurrStaking
 * @notice Tier system and staking model
 */
contract PurrStaking is IPurrStaking, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 public immutable SECOND_YEAR;

    uint16 public poolId;
    uint256 public itemId;

    IERC20 public launchPadToken;

    mapping(PoolType poolType => PoolInfo pool) public poolInfo;
    mapping(uint256 itemId => UserPoolInfo userPool) public userPoolInfo;

    constructor(address _launchPadToken, address _initialOnwer) Ownable(_initialOnwer) {
        launchPadToken = IERC20(_launchPadToken);
        SECOND_YEAR = 31_536_000;
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
    function stake(uint256 _amount, PoolType _poolType) external nonReentrant{
        address sender = msg.sender;
        PoolInfo storage pool = poolInfo[_poolType];
        uint256 point = _amount.mulDiv(pool.multiplier,10, Math.Rounding.Floor);

        if (_amount <= 0) {
            revert InvalidAmount(_amount);
        }

        if(_poolType != PoolType.ONE || _poolType != PoolType.TWO || _poolType != PoolType.THREE || _poolType != PoolType.FOUR) {
            // revert 
        }

        pool.totalStaked += _amount;
        ++pool.numberStaker;

        // update user pool infor
        ++itemId;
        userPoolInfo[itemId] = UserPoolInfo({
            staker: msg.sender,
            pPoint: point,
            stakedAmount: _amount,
            start: block.timestamp,
            end: block.timestamp + pool.lockDay,
            timeUnstaked: 0, 
            poolType: _poolType
        });

        IERC20(launchPadToken).safeTransferFrom(sender, address(this), _amount);

        emit Stake(sender, itemId, _amount, point, block.timestamp, block.timestamp + pool.lockDay, _poolType);
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
     * @param _itemId The item id. 
     */
     function unstake(uint256 _amount, uint256 _itemId) external nonReentrant{
        UserPoolInfo storage userPool = userPoolInfo[_itemId]; 
        PoolType poolType = userPool.poolType; 
        PoolInfo storage pool = poolInfo[poolType]; 
        
        if (_amount <= 0) {
            revert InvalidAmount(_amount);
        }
        
        if(poolType == PoolType.ONE) {
            userPoolInfo[itemId].timeUnstaked = block.timestamp; 
            // emit 
        } else if(poolType == PoolType.TWO) {

        } else if(poolType == PoolType.THREE) {

        } else if(poolType == PoolType.FOUR) {  
            
        }

     }

    function getPendingReward(uint256 _itemId) external view returns (uint256) {
        return _calculatePendingReward(_itemId);
    }

    function claimReward(uint256 _itemId) external {
        if (msg.sender != userPoolInfo[_itemId].staker) {
            revert InvalidStaker(msg.sender);
        }
        uint256 reward = _calculatePendingReward(_itemId);

        if (launchPadToken.balanceOf(address(this)) < reward) {
            revert InsufficientBalance(launchPadToken.balanceOf(address(this)));
        }

        IERC20(launchPadToken).safeTransfer(msg.sender, reward);
    }

    function updatePool(PoolInfo memory _pool) external onlyOwner {
        poolInfo[_pool.poolType] = _pool;

        emit UpdatePool(_pool);
    }

 

    function _calculatePendingReward(uint256 _itemId) internal view returns (uint256) {
        UserPoolInfo memory userPool = userPoolInfo[_itemId];
        PoolInfo memory pool = poolInfo[userPool.poolType];
        uint256 timeStaked = block.timestamp - userPool.start;
        uint256 timeStakedMulApr = timeStaked * pool.apr;
        uint256 div = 100_000 * SECOND_YEAR;

        return userPool.stakedAmount.mulDiv(timeStakedMulApr, div, Math.Rounding.Floor);
    }
}
