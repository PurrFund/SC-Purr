// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { PoolType, PoolInfo, TierInfo } from "../types/PurrStaingType.sol";

/**
 * @title IPurrStaking interface.
 */
interface IPurrStaking {
    // event list
    event Stake(
        address indexed staker,
        uint256 indexed itemId,
        uint256 amount,
        uint256 pPoint,
        uint64 updateAt,
        uint64 end,
        PoolType poolType
    );
    event UnStake(address indexed staker, uint256 itemId, uint256 unStakeAmount, uint256 lossPoint, uint64 time, PoolType pool);
    event ClaimReward(address indexed claimer, uint256 itemId, uint256 amount, uint64 claimAt);
    event UpdatePool(PoolInfo pool);
    event UpdateTier(TierInfo tier);
    event ClaimUnstakePoolOne(address staker, uint256 itemId, uint256 amount, uint64 claimTime);
    event ClaimPendingReward(address staker, uint256 itemId, uint256 amount, uint64 claimTime);

    // error list
    error InsufficientAmount(uint256 amount);
    error InsufficientAlowances(uint256 amount);
    error ExceedBalance(uint256 amount);
    error InvalidPoint(uint256 point);
    error InvalidAmount(uint256 amount);
    error InvalidStaker(address staker);
    error InsufficientBalance(uint256 amount);
    error InvalidPoolType();
    error InvalidItemId(uint256 itemId);
    error CanNotWithClaimPoolOne();

    /**
     * @notice Stake token to pool.
     *
     * @dev Will update user's point base on user's balance.
     * @dev Emit a {Stake} event.
     *
     * Requirements:
     *   -  Sender must approve amount token's staking for this contract more than {amount}.
     *   -  PoolType must be valid, must follow in {PoolType}.
     *   -  Amount must greater than zero.
     *
     * @param _amount The amount user will stake.
     * @param _poolType The type of pool.
     */
    function stake(uint256 _amount, PoolType _poolType) external;

    /**
     * @notice Unstake token's protocol.
     *
     * @dev Will update user's point base on user's balance.
     * @dev Base on lockday, unstake fee and unstake time of each pool will update and calculate amount staker will get.
     * @dev Emit a {UnStake} event.
     *
     * Requirements:
     *   - Amount must be smaller than current balance staked corresponding that itemId.
     *   - Sender must be owner of item.
     *   - ItemId must be valid.
     *
     * @param _amount The amount user will stake.
     * @param _itemId The item id.
     */
    function unstake(uint256 _amount, uint256 _itemId) external;

    /**
     * @notice Claim token from pool one after unstake.
     *
     * @dev Will withdraw all amount available after {unstakeTime} from the time unstake.
     *
     * Requirements:
     *   - Sender must be owner of item.
     *   - Itemid must be valid.
     *   - The current timestamp must be greater than 10 days from the time unstake.
     *   - The poolType must be type {ONE}.
     *
     * @param _itemId The item id.
     */
    function claimUnstakePoolOne(uint256 _itemId) external;

    /**
     * @notice Get current pending reward.
     *
     * @param _itemId The item id.
     *
     * @return The pending reward.
     */
    function getPendingReward(uint256 _itemId) external view returns (uint256);

    /**
     * @notice Get total reward in the past.
     *
     * @param _itemId The item id.
     *
     * @return The pending reward.
     */
    function getTotalReward(uint256 _itemId) external view returns (uint256);

    /**
     * @notice Claim token pending reward.
     *
     * Requirements:
     *   - Sender must be owner of item.
     *
     * @param _itemId The item id.
     */
    function claimReward(uint256 _itemId) external;

    /**
     * @notice Update pool data.
     *
     * Requirements:
     *   - Sender must be owner.
     *
     * @param _pool The pool type.
     */
    function updatePool(PoolInfo memory _pool) external;

    /**
     * @notice Update pool tier.
     *
     * Requirements:
     *   - Sender must be owner.
     *
     * @param _tier The pool type.
     */
    function updateTier(TierInfo memory _tier) external;

    /**
     * @notice Get analysis staking system.
     *
     * @return totalStaked The total amount user stake.
     * @return totalNumberStaker The number user stake.
     * @return totalReward The total current pending reward.
     * @return avgAPY The average APY.
     */
    function getTotalStakedPool()
        external
        view
        returns (uint256 totalStaked, uint256 totalNumberStaker, uint256 totalReward, uint256 avgAPY);

    /**
     * @notice Get staker's analysis staking system.
     *
     * @param _user The user's address
     *
     * @return totalStaked The total amount of sender.
     * @return totalPoint The total amount point of sender.
     * @return totalReward The total reward of sender.
     * @return balance The total current balance launchpad token of sender.
     */
    function getUserTotalStaked(address _user)
        external
        view
        returns (uint256 totalStaked, uint256 totalPoint, uint256 totalReward, uint256 balance);

    /**
     * @notice Get list staker's itemId.
     *
     * @param _user The user's address
     *
     * @return The list staker's itemId.
     */
    function getUserItemId(address _user) external view returns (uint256[] memory);

    /**
     * @notice Add fund to contract.
     *
     * Requirements:
     *   - Sender must be owner.
     *
     * @param _amount The plus amount.
     */
    function addFund(uint256 _amount) external;

    /**
     * @notice Emergency Withdraw.
     *
     * Requirements:
     *   - Sender must be owner.
     *
     * @param _amount The withdraw amount.
     */
    function withdrawFund(uint256 _amount) external;

    /**
     * @notice Pause stake, unstake, claim feature on contract.
     *
     * Requirements:
     *   - Sender must be owner.
     */
    function pause() external;

    /**
     * @notice Unpause stake, unstake, claim feature on contract.
     *
     * Requirements:
     *   - Sender must be owner.
     */
    function unpause() external;
}
