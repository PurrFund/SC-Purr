// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct UserPoolInfo {
    uint64 updateAt;
    uint64 end;
    // use when poolType is ONE
    uint64 timeUnstaked;
    // user when poolType is ONE
    uint256 amountAvailable;
    address staker;
    // multiple * 10e18
    uint256 pPoint;
    uint256 stakedAmount;
    PoolType poolType;
}

struct TierInfo {
    // multiple * 100
    // example : 6.12% => 612
    uint16 lotteryProbabilities;
    uint16 poolWeight;
    uint256 pPoint;
    TierType tierType;
}

struct PoolInfo {
    // multiple * 100
    // example: 9% => 900
    uint16 unstakeFee;
    // multiple * 100
    // example: 15.55% => 1555, 1% => 100
    uint16 apy;
    // multiple * 10
    // example: 1.5 => 15
    uint16 multiplier;
    uint32 lockDay;
    uint32 unstakeTime;
    uint256 totalStaked;
    uint256 numberStaker;
    PoolType poolType;
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
