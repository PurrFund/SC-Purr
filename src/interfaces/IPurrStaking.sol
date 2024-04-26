// SPDX-License-Identifer: MIT
pragma solidity ^0.8.20;

import { PoolType, PoolInfo, TierInfo, TierType } from "../types/PurrStaingType.sol";

interface IPurrStaking {
    // event list
    event Stake(
        address indexed staker,
        uint256 indexed itemId,
        uint256 amount,
        uint256 point,
        uint64 updateAt,
        uint64 end,
        PoolType poolType
    );
    event UnStake(address indexed staker, uint256 amount, uint256 point, uint64 time, PoolType pool);
    event ClaimReward(address indexed claimer, uint256 amount, uint64 claimAt);
    event UpdatePool(PoolInfo pool);
    event UpdateTier(TierInfo tier);

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
     * @notice Stake token's protocol.
     *
     * @dev Will update user's point base on user's balance.
     * @dev Emit a {Stake} event.
     *
     * Requirements:
     *   - Require sender approve amount token's staking for this contract more than {amount}.
     *
     * @param _amount The amount user will stake.
     * @param _poolType The type of pool.
    */
    function stake(uint256 _amount, PoolType _poolType) external;

    /**
     * @notice Unstake token's protocol.
     *
     * @dev Will update user's point base on user's balance.
     * @dev Emit a {UnStake} event.
     *
     * Requirements:
     *   - Amount must be smaller than current balance stake.
     *   - Sender must be owner of item.
     *
     * @param _amount The amount user will stake.
     * @param _itemId The item id.
     */
    function unstake(uint256 _amount, uint256 _itemId) external;

    /**
     * @notice Claim token from pool one after unstake.
     *
     * @dev Will update user's amount avaiable to zero.
     * @dev Emit a {UnStake} event.
     *
     * Requirements:
     *   - Sender must be owner of item.
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
     * @return The analysis staking system.
     */
    function getTotalStakedPool() external view returns (uint256, uint256, uint256, uint256);

    /**
     * @notice Get staker's analysis staking system.
     *
     * @return The staker's analysis staking system.
     */
    function getUserTotalStaked() external view returns (uint256, uint256);

    /**
     * @notice Get list staker's itemId.
     *
     * @return The list staker's itemId.
     */
    function getUserItemId() external view returns (uint256[] memory);

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
    function emergencyWithdraw(uint256 _amount) external;

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
