// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

enum PoolState {
    INIT,
    STARTING,
    PAUSE,
    END
}

struct Pool {
    uint256 id;
    string projectId;
    uint256 tge;
    uint256 cliff;
    uint256 unlockPercent;
    uint256 linearVestingDuration;
    uint16[] percents;
    uint64[] times;
    uint256 fundsTotal;
    uint256 fundsClaimed;
    address tokenFund;
    string name;
    VestingType vestingType;
    PoolState state;
}

struct CreatePool {
    string projectId;
    uint256 tge;
    uint256 cliff;
    uint256 unlockPercent;
    uint256 linearVestingDuration;
    uint16[] percents;
    uint64[] times;
    address tokenFund;
    string name;
    VestingType vestingType;
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
