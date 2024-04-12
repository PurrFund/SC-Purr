// SPDX-License-Identifer: MIT
pragma solidity ^0.8.20;

import { PoolType } from "../types/PurrStaingType.sol";

contract IPurrStaking {
    // event list
    event Stake(address indexed staker, uint256 amount, uint256 time, uint256 point, uint256 weight, PoolType tier);
    event UnStake(address indexed staker, uint256 amount, uint256 time, uint256 point, uint256 weight, PoolType tier);

    // error list
    error InsufficientAmount(uint256 amount);
    error InsufficientAlowances(uint256 amount);
    error ExceedBalance(uint256 amount);
    error InvalidPoint(uint256 point);
    error InvalidAmount(uint256 amount);
}
