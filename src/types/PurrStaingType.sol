// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct UserPower {
    Power power;
    uint256 pPoint;
    uint256 weight;
    uint256 balance;
    uint256 timeLocked;
    uint256 multipler;
    PoolType tier;
}

struct PowerSystem {
    uint256 weight;
    uint256 amount;
}

struct PoolInfo {
    // mul * 100 to handle float
    uint16 multiplier;
    uint256 minWeight;
    uint256 minPoint;
    uint256 apr;
    uint256 lockPeriodInDays;
    uint256 totalStaked;
    uint256 numberStaker;
    PoolStatus status;
    PoolType poolType;
}

enum Power {
    ZERO,
    ONE,
    TWO,
    THREE,
    FOUR,
    FIVE,
    SIX
}

enum PoolStatus {
    ACTIVE,
    STOP
}

enum PoolType {
    ZERO,
    BZONZE,
    SLIVER,
    GOLD,
    DIAMOND
}
