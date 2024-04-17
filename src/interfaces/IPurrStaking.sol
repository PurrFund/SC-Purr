// SPDX-License-Identifer: MIT
pragma solidity ^0.8.20;

import { PoolType, PoolInfo } from "../types/PurrStaingType.sol";

contract IPurrStaking {
    // event list
    event Stake(
        address indexed staker,
        uint256 indexed itemId,
        uint256 amount,
        uint256 point,
        uint256 start,
        uint256 end,
        PoolType poolType
    );
    event UnStake(address indexed staker, uint256 amount, uint256 time, uint256 point, uint256 weight, PoolType tier);
    event UpdatePool(PoolInfo pool);

    // error list
    error InsufficientAmount(uint256 amount);
    error InsufficientAlowances(uint256 amount);
    error ExceedBalance(uint256 amount);
    error InvalidPoint(uint256 point);
    error InvalidAmount(uint256 amount);
    error InvalidStaker(address staker);
    error InsufficientBalance(uint256 amount);
}
