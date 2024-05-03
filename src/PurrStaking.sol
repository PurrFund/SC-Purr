// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import { UserPoolInfo, PoolInfo, PoolType, TierType, TierInfo } from "./types/PurrStaingType.sol";
import { IPurrStaking } from "./interfaces/IPurrStaking.sol";
import { PurrToken } from "./token/PurrToken.sol";

/**
 * @notice PurrStaking contract.
 */
contract PurrStaking is IPurrStaking, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for PurrToken;
    using Math for uint256;

    uint256 public immutable SECOND_YEAR;

    uint256 public itemId;

    PurrToken public launchPadToken;

    mapping(uint256 itemId => UserPoolInfo userPool) public userPoolInfo;
    mapping(address staker => uint256[] itemIds) public userItemInfo;
    mapping(uint256 itemId => uint256 index) public itemIdIndexInfo;

    mapping(TierType tierType => TierInfo tier) public tierInfo;
    mapping(PoolType poolType => PoolInfo pool) public poolInfo;

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

        // upadte poolInfo
        poolInfo[PoolType.ONE] = _pools[0];
        poolInfo[PoolType.TWO] = _pools[1];
        poolInfo[PoolType.THREE] = _pools[2];
        poolInfo[PoolType.FOUR] = _pools[3];

        // update tierinfor
        tierInfo[TierType.ONE] = _tiers[0];
        tierInfo[TierType.TWO] = _tiers[1];
        tierInfo[TierType.THREE] = _tiers[2];
        tierInfo[TierType.FOUR] = _tiers[3];
        tierInfo[TierType.FIVE] = _tiers[4];
        tierInfo[TierType.SIX] = _tiers[5];
    }

    /**
     * @inheritdoc IPurrStaking
     */
    function stake(uint256 _amount, PoolType _poolType) external whenNotPaused nonReentrant {
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
            staker: sender,
            pPoint: point,
            stakedAmount: _amount,
            poolType: _poolType
        });

        // add item to user's list itemId
        uint256 length = userItemInfo[sender].length;
        userItemInfo[sender].push(itemId);
        itemIdIndexInfo[itemId] = length;

        PurrToken(launchPadToken).safeTransferFrom(sender, address(this), _amount);

        emit Stake(sender, itemId, _amount, point, uint64(block.timestamp), uint64(block.timestamp + pool.lockDay), _poolType);
    }

    /**
     * @inheritdoc IPurrStaking
     */
    function unstake(uint256 _amount, uint256 _itemId) external whenNotPaused nonReentrant {
        address sender = msg.sender;
        UserPoolInfo storage userPool = userPoolInfo[_itemId];
        PoolType poolType = userPool.poolType;
        PoolInfo storage pool = poolInfo[poolType];
        uint256 prePPoint = userPool.pPoint;

        if (_amount <= 0 || _amount > userPool.stakedAmount) {
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

        // calculate pending reward
        uint256 reward = _calculatePendingReward(userPool);

        // update userPool infor
        userPool.stakedAmount -= _amount;
        userPool.pPoint = userPool.stakedAmount.mulDiv(pool.multiplier, 10, Math.Rounding.Floor);
        userPool.updateAt = uint64(block.timestamp);

        // update poolInfo
        pool.totalStaked -= _amount;
        if (userPool.stakedAmount == 0) {
            pool.numberStaker -= 1;
        }

        uint256 totalWithDraw = _amount + reward;

        if (poolType == PoolType.ONE) {
            if (uint64(block.timestamp) > end) {
                PurrToken(launchPadToken).safeTransfer(sender, totalWithDraw);
                if (userPool.stakedAmount == 0) {
                    delete userPoolInfo[_itemId];
                    delete userItemInfo[msg.sender][itemIdIndexInfo[itemId]];
                    delete itemIdIndexInfo[itemId];
                }
            } else if (uint64(block.timestamp) <= end) {
                userPool.timeUnstaked = uint64(block.timestamp) + pool.unstakeTime;
                userPool.amountAvailable = totalWithDraw;
            }
        } else if (poolType == PoolType.TWO || poolType == PoolType.THREE || poolType == PoolType.FOUR) {
            if (uint64(block.timestamp) > end) {
                PurrToken(launchPadToken).safeTransfer(sender, totalWithDraw);
            } else if (uint64(block.timestamp) <= end) {
                uint256 burnAmount = _amount.mulDiv(unstakeFee, 10_000, Math.Rounding.Floor);
                uint256 remainAmount = totalWithDraw - burnAmount;
                PurrToken(launchPadToken).safeTransfer(sender, remainAmount);
                PurrToken(launchPadToken).burn(burnAmount);
            }
            if (userPool.stakedAmount == 0) {
                delete userPoolInfo[_itemId];
                delete userItemInfo[msg.sender][itemIdIndexInfo[itemId]];
                delete itemIdIndexInfo[itemId];
            }
        }

        emit UnStake(sender, _itemId, _amount, prePPoint - userPool.pPoint, uint64(block.timestamp), poolType);
    }

    /**
     * @inheritdoc IPurrStaking
     */
    function claimUnstakePoolOne(uint256 _itemId) external whenNotPaused nonReentrant {
        address sender = msg.sender;
        UserPoolInfo storage userPool = userPoolInfo[_itemId];

        if (_itemId <= 0) {
            revert InvalidItemId(_itemId);
        }

        if (block.timestamp <= userPool.timeUnstaked) {
            revert CanNotWithClaimPoolOne();
        }

        if (userPool.poolType != PoolType.ONE) {
            revert InvalidPoolType();
        }

        if (sender != userPool.staker) {
            revert InvalidStaker(msg.sender);
        }

        PurrToken(launchPadToken).safeTransfer(msg.sender, userPool.amountAvailable);

        if (userPool.stakedAmount == 0) {
            delete userPoolInfo[_itemId];
            delete userItemInfo[msg.sender][itemIdIndexInfo[itemId]];
            delete itemIdIndexInfo[itemId];
        }

        emit ClaimUnstakePoolOne(sender, _itemId, userPool.amountAvailable, uint64(block.timestamp));

        userPool.amountAvailable = 0;
        userPool.timeUnstaked = 0;
    }

    /**
     * @inheritdoc IPurrStaking
     */
    function getPendingReward(uint256 _itemId) external view returns (uint256) {
        UserPoolInfo memory userPool = userPoolInfo[_itemId];
        return _calculatePendingReward(userPool);
    }

    /**
     * @inheritdoc IPurrStaking
     */
    function claimReward(uint256 _itemId) external whenNotPaused nonReentrant {
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

        emit ClaimPendingReward(sender, _itemId, reward, uint64(block.timestamp));
    }

    /**
     * @inheritdoc IPurrStaking
     */
    function updatePool(PoolInfo memory _pool) external onlyOwner {
        poolInfo[_pool.poolType] = _pool;

        emit UpdatePool(_pool);
    }

    /**
     * @inheritdoc IPurrStaking
     */
    function updateTier(TierInfo memory _tier) external onlyOwner {
        tierInfo[_tier.tierType] = _tier;

        emit UpdateTier(_tier);
    }

    /**
     * @inheritdoc IPurrStaking
     */
    function addFund(uint256 _amount) external onlyOwner {
        if (_amount <= 0) {
            revert InvalidAmount(_amount);
        }

        PurrToken(launchPadToken).safeTransferFrom(msg.sender, address(this), _amount);
    }

    /**
     * @inheritdoc IPurrStaking
     */
    function withdrawFund(uint256 _amount) external onlyOwner {
        uint256 totalStaked = poolInfo[PoolType.ONE].totalStaked + poolInfo[PoolType.TWO].totalStaked
            + poolInfo[PoolType.THREE].totalStaked + poolInfo[PoolType.FOUR].totalStaked;

        if (launchPadToken.balanceOf(address(this)) - totalStaked < _amount) {
            revert InvalidAmount(_amount);
        }

        PurrToken(launchPadToken).safeTransfer(msg.sender, _amount);
    }

    /**
     * @inheritdoc IPurrStaking
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @inheritdoc IPurrStaking
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @inheritdoc IPurrStaking
     */
    function getTotalStakedPool()
        external
        view
        returns (uint256 totalStaked, uint256 totalNumberStaker, uint256 totalReward, uint256 avgAPY)
    {
        PoolInfo memory poolOne = poolInfo[PoolType.ONE];
        PoolInfo memory poolTwo = poolInfo[PoolType.TWO];
        PoolInfo memory poolThree = poolInfo[PoolType.THREE];
        PoolInfo memory poolFour = poolInfo[PoolType.FOUR];

        totalStaked = poolOne.totalStaked + poolTwo.totalStaked + poolThree.totalStaked + poolFour.totalStaked;
        totalNumberStaker = poolOne.numberStaker + poolTwo.numberStaker + poolThree.numberStaker + poolFour.numberStaker;
        totalReward = 0;
        uint256 i = 1;
        for (; i <= itemId;) {
            totalReward += _calculatePendingReward(userPoolInfo[i]);

            unchecked {
                ++i;
            }
        }

        uint256 totalApy = poolOne.apy + poolTwo.apy + poolThree.apy + poolFour.apy;
        avgAPY = totalApy / 4;

        return (totalStaked, totalNumberStaker, totalReward, avgAPY);
    }

    /**
     * @inheritdoc IPurrStaking
     */
    function getUserTotalStaked(address _user)
        external
        view
        returns (uint256 totalStaked, uint256 totalPoint, uint256 totalReward, uint256 balance)
    {
        uint256[] memory itemIds = userItemInfo[_user];
        uint256 length = itemIds.length;
        balance = launchPadToken.balanceOf(_user);

        for (uint256 i; i < length;) {
            totalStaked += userPoolInfo[itemIds[i]].stakedAmount;
            totalPoint += userPoolInfo[itemIds[i]].pPoint;
            totalReward += _calculatePendingReward(userPoolInfo[itemIds[i]]);

            unchecked {
                ++i;
            }
        }

        return (totalStaked, totalPoint, totalReward, balance);
    }

    /**
     * @inheritdoc IPurrStaking
     */
    function getUserItemId(address _user) external view returns (uint256[] memory) {
        return userItemInfo[_user];
    }

    function _calculatePendingReward(UserPoolInfo memory userPool) internal view returns (uint256) {
        PoolInfo memory pool = poolInfo[userPool.poolType];
        uint256 timeStaked = block.timestamp - userPool.updateAt;
        uint256 timeStakedMulApy = timeStaked * pool.apy;
        uint256 div = 10_000 * SECOND_YEAR;

        return userPool.stakedAmount.mulDiv(timeStakedMulApy, div, Math.Rounding.Floor);
    }
}
