// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { UserPoolInfo, PoolInfo, PoolType, TierType, TierInfo } from "./types/PurrStaingType.sol";
import { IPurrStaking } from "./interfaces/IPurrStaking.sol";
import { PurrToken } from "./token/PurrToken.sol";

/**
 * @title PurrStaking
 * @notice
 */
contract PurrStaking is IPurrStaking, Ownable, ReentrancyGuard {
    using SafeERC20 for PurrToken;
    using Math for uint256;

    uint256 public immutable SECOND_YEAR;

    uint256 public itemId;

    PurrToken public launchPadToken;

    mapping(PoolType poolType => PoolInfo pool) public poolInfo;
    mapping(uint256 itemId => UserPoolInfo userPool) public userPoolInfo;
    mapping(address staker => uint256[] itemIds) public userItemInfo;
    mapping(TierType tierType => TierInfo tier) public tierInfo;

    constructor(
        address _launchPadToken,
        address _initialOnwer,
        PoolInfo[] memory _pools,
        TierInfo[] memory _tiers
    )
        Ownable(_initialOnwer)
    {
        launchPadToken = PurrToken(_launchPadToken);
        SECOND_YEAR = 31_536_000;
        poolInfo[PoolType.ONE] = _pools[0];
        poolInfo[PoolType.TWO] = _pools[1];
        poolInfo[PoolType.THREE] = _pools[2];
        poolInfo[PoolType.FOUR] = _pools[3];
        tierInfo[TierType.ONE] = _tiers[0];
        tierInfo[TierType.TWO] = _tiers[1];
        tierInfo[TierType.THREE] = _tiers[2];
        tierInfo[TierType.FOUR] = _tiers[3];
        tierInfo[TierType.FIVE] = _tiers[4];
        tierInfo[TierType.SIX] = _tiers[5];
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
    function stake(uint256 _amount, PoolType _poolType) external nonReentrant {
        address sender = msg.sender;
        PoolInfo storage pool = poolInfo[_poolType];
        uint256 point = _amount.mulDiv(pool.multiplier, 10, Math.Rounding.Floor);

        if (_amount <= 0) {
            revert InvalidAmount(_amount);
        }

        if (uint8(_poolType) > 3) {
            revert InvalidPoolType();
        }

        // update pool data
        pool.totalStaked += _amount;
        ++pool.numberStaker;

        ++itemId;

        // create new item
        userPoolInfo[itemId] = UserPoolInfo({
            updateAt: uint64(block.timestamp),
            end: uint64(block.timestamp + pool.lockDay),
            timeUnstaked: 0,
            amountAvailable: 0,
            staker: msg.sender,
            pPoint: point,
            stakedAmount: _amount,
            poolType: _poolType
        });

        // add item to user's list itemId
        userItemInfo[sender].push(itemId);

        PurrToken(launchPadToken).safeTransferFrom(sender, address(this), _amount);

        emit Stake(sender, itemId, _amount, point, uint64(block.timestamp), uint64(block.timestamp + pool.lockDay), _poolType);
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
    function unstake(uint256 _amount, uint256 _itemId) external nonReentrant {
        address sender = msg.sender;
        UserPoolInfo storage userPool = userPoolInfo[_itemId];
        PoolType poolType = userPool.poolType;
        PoolInfo storage pool = poolInfo[poolType];

        if (_amount <= 0 || _amount >= userPool.stakedAmount) {
            revert InvalidAmount(_amount);
        }

        if (_itemId <= 0) {
            revert InvalidItemId(_itemId);
        }

        if (sender != userPool.staker) {
            revert InvalidStaker(sender);
        }

        uint16 unstakeFee = pool.unstakeFee;
        uint64 end = userPool.end;
        uint256 reward = _calculatePendingReward(userPool);
        userPool.stakedAmount -= _amount;
        userPool.pPoint = userPool.stakedAmount.mulDiv(pool.multiplier, 10, Math.Rounding.Floor);
        userPool.updateAt = uint64(block.timestamp);

        if (poolType == PoolType.ONE) {
            userPool.timeUnstaked = uint64(block.timestamp) + pool.unstakeTime;
            userPool.amountAvailable = _amount;
        } else if (poolType == PoolType.TWO || poolType == PoolType.THREE || poolType == PoolType.FOUR) {
            uint256 totalWithDraw = _amount + reward;

            if (uint64(block.timestamp) > end) {
                PurrToken(launchPadToken).safeTransfer(sender, totalWithDraw);
            } else if (uint64(block.timestamp) < end) {
                uint256 remainAmount = totalWithDraw.mulDiv(unstakeFee, 10_000, Math.Rounding.Floor);
                PurrToken(launchPadToken).safeTransfer(sender, remainAmount);
                PurrToken(launchPadToken).burn(totalWithDraw - remainAmount);
            }
        }

        if (userPool.stakedAmount == 0 && poolType != PoolType.ONE) {
            delete userPoolInfo[_itemId];
            delete userItemInfo[msg.sender][_itemId];
        }

        emit UnStake(sender, _amount, userPool.pPoint, uint64(block.timestamp), poolType);
    }

    function claimUnstakePoolOne(uint256 _itemId) external nonReentrant {
        address sender = msg.sender;
        UserPoolInfo storage userPool = userPoolInfo[_itemId];

        if (_itemId <= 0) {
            revert InvalidItemId(_itemId);
        }

        if (userPool.poolType != PoolType.ONE) {
            revert InvalidPoolType();
        }

        if (sender != userPool.staker) {
            revert InvalidStaker(msg.sender);
        }
        PurrToken(launchPadToken).safeTransfer(msg.sender, userPool.amountAvailable);

        userPool.amountAvailable = 0;

        if (userPool.stakedAmount == 0) {
            delete userPoolInfo[_itemId];
            delete userItemInfo[msg.sender][_itemId];
        }
    }

    function getPendingReward(uint256 _itemId) external view returns (uint256) {
        UserPoolInfo memory userPool = userPoolInfo[_itemId];
        return _calculatePendingReward(userPool);
    }

    // update start time
    function claimReward(uint256 _itemId) external nonReentrant{
        address sender = msg.sender; 
        UserPoolInfo memory userPool = userPoolInfo[_itemId];

        if (sender != userPool.staker) {
            revert InvalidStaker(sender);
        }
        uint256 reward = _calculatePendingReward(userPool);

        if (launchPadToken.balanceOf(address(this)) < reward) {
            revert InsufficientBalance(launchPadToken.balanceOf(address(this)));
        }

        userPoolInfo[_itemId].updateAt = uint64(block.timestamp);

        PurrToken(launchPadToken).safeTransfer(sender, reward);
        
        emit ClaimReward(sender,  reward, uint64(block.timestamp));
    }

    function updatePool(PoolInfo memory _pool) external onlyOwner {
        poolInfo[_pool.poolType] = _pool;

        emit UpdatePool(_pool);
    }

    function updateTier(TierType _tierType, TierInfo memory tier) external onlyOwner {
        tierInfo[_tierType] = tier;

        emit UpdateTier(_tierType, tier);
    }

    // how to calculate AVG APR
    // how to caculate reward
    function getTotalStakedPool() external view returns (uint256, uint256, uint256, uint256) {
        PoolInfo memory poolOne = poolInfo[PoolType.ONE];
        PoolInfo memory poolTwo = poolInfo[PoolType.TWO];
        PoolInfo memory poolThree = poolInfo[PoolType.THREE];
        PoolInfo memory poolFour = poolInfo[PoolType.FOUR];

        uint256 totalStaked = poolOne.totalStaked + poolTwo.totalStaked + poolThree.totalStaked + poolFour.totalStaked;
        uint256 totalNumberStaker = poolOne.numberStaker + poolTwo.numberStaker + poolThree.numberStaker + poolFour.numberStaker;
        uint256 totalReward = 0;
        uint256 avgAPR = 0;

        return (totalStaked, totalNumberStaker, totalReward, avgAPR);
    }

    function getUserTotalStaked() external view returns (uint256, uint256) {
        uint256[] memory itemIds = userItemInfo[msg.sender];
        uint256 length = itemIds.length;
        uint256 totalStaked;
        uint256 totalPoint;

        for (uint256 i; i < length;) {
            totalStaked += userPoolInfo[itemIds[i]].stakedAmount;
            totalPoint += userPoolInfo[itemIds[i]].pPoint;

            unchecked {
                ++i;
            }
        }

        return (totalStaked, totalPoint);
    }

    function getUserItemId() external view returns (uint256[] memory) {
        return userItemInfo[msg.sender];
    }

    function _calculatePendingReward(UserPoolInfo memory userPool) internal view returns (uint256) {
        PoolInfo memory pool = poolInfo[userPool.poolType];
        uint256 timeStaked = block.timestamp - userPool.updateAt;
        uint256 timeStakedMulApr = timeStaked * pool.apr;
        uint256 div = 100_000 * SECOND_YEAR;

        return userPool.stakedAmount.mulDiv(timeStakedMulApr, div, Math.Rounding.Floor);
    }
}
