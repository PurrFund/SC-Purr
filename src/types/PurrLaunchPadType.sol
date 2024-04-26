// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct Project {
    uint64 id;
    address owner;
    address tokenIDO;
    string name;
    string twitter;
    string discord;
    string telegram;
    string website;
}

struct PreProject {
    address owner;
    address tokenIDO;
    string name;
    string twitter;
    string discord;
    string telegram;
    string website;
}

struct LaunchPad{
    uint16 unlockPercent;
    uint64 startTime;
    uint64 snapshotTime;
    uint64 autoVestingTime;
    uint64 vestingTime;
    uint16[] percents;
    uint64[] times;
    uint256 tge;
    uint256 cliffTime;
    uint256 linearTime;
    uint256 tokenOffer;
    uint256 tokenPrice;
    uint256 totalRaise;
    uint256 ticketSize;
    VestingType typeVesting;
}

struct LaunchPool{
    uint16 unlockPercent;
    uint64 startTime;
    uint64 snapshotTime;
    uint64 autoVestingTime;
    uint64 vestingTime;
    uint16[] percents;
    uint64[] times;
    uint256 tge;
    uint256 cliffTime;
    uint256 linearTime;
    uint256 tokenReward;
    uint256 totalAirdrop;
    VestingType typeVesting;
}

enum VestingType {
    VESTING_TYPE_MILESTONE_CLIFF_FIRST,
    VESTING_TYPE_MILESTONE_UNLOCK_FIRST,
    VESTING_TYPE_LINEAR_UNLOCK_FIRST,
    VESTING_TYPE_LINEAR_CLIFF_FIRST
}
