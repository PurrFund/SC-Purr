// SPDX-License-Identifer: MIT
pragma solidity ^0.8.20;

import { PoolType, PoolInfo, TierInfo, TierType } from "../types/PurrStaingType.sol";

contract IPurrStaking {
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
    event UpdateTier(TierType _tierType, TierInfo tier);

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
}
