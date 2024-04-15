// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct UserPoolInfo {
    address staker;
    uint256 pPoint;
    uint256 stakedAmount;
    uint256 start;
    uint256 end;
    PoolType poolType;
}

struct TierInfo {
    uint16 lotteryProbabilities;
    uint16 poolWeight;
    uint256 pPoint;
    TierType tierType;
    Weight weight;
}

struct PoolInfo {
    // form in 4 digit
    uint16 apr;
    uint8 unstakeFee;
    uint16 multiplier;
    uint32 lockDay;
    uint32 unstakeTime;
    uint256 totalStaked;
    uint256 numberStaker;
    PoolType poolType;
}

struct UserPool {
    uint256 balance;
    uint256 pPoint;
}

enum Weight {
    ZERO,
    ONE,
    TWO,
    THREE,
    FOUR,
    FIVE,
    SIX
}

enum PoolType {
    ONE,
    TWO,
    THREE,
    FOUR
}

enum TierType {
    ZERO,
    ONE,
    TWO,
    THREE,
    FOUR,
    FIVE,
    SIX
}
