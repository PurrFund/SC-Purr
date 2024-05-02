// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

enum PoolState {
    NEW,
    STARTING,
    PAUSE,
    SUCCESS
}

struct Pool {
    address tokenFund;
    uint256 id;
    string name;
    uint8 vestingType;
    uint256 tge;
    uint256 cliff;
    uint256 unlockPercent;
    uint256 linearVestingDuration;
    uint256[] milestoneTimes;
    uint256[] milestonePercents;
    //     mapping(address => uint256) funds;
    //     mapping(address => uint256) released;
    uint256 fundsTotal;
    uint256 fundsClaimed;
    PoolState state;
}

struct UserPool {
    uint256 fund;
    uint256 released;
}
