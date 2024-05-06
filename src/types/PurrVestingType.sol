// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

enum PoolState {
    INIT,
    STARTING,
    PAUSE,
    END
}

struct Pool {
    uint256 id;
    uint256 tge;
    uint256 cliff;
    uint256 unlockPercent;
    uint256 linearVestingDuration;
    uint256[] times;
    uint256[] percens;
    uint256 fundsTotal;
    uint256 fundsClaimed;
    address tokenFund;
    string name;
    VestingType vestingType;
    PoolState state;
}

struct CreatePool {
    uint256 tge;
    uint256 cliff;
    uint256 unlockPercent;
    uint256 linearVestingDuration;
    uint256[] times;
    uint256[] percens;
    uint256 fundsTotal;
    uint256 fundsClaimed;
    address tokenFund;
    string name;
    VestingType vestingType;
    PoolState state;
}

struct UserPool {
    uint256 fund;
    uint256 released;
}

enum VestingType {
    VESTING_TYPE_MILESTONE_CLIFF_FIRST,
    VESTING_TYPE_MILESTONE_UNLOCK_FIRST,
    VESTING_TYPE_LINEAR_UNLOCK_FIRST,
    VESTING_TYPE_LINEAR_CLIFF_FIRST
}