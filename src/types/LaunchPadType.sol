// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct Project {
    uint64 id;
    address owner;
    address tokenIDO;
    address tokenUseToBuy;
    bool isRequireKyc;
    bool isRequireStake;
    bool isRequrieVesting;
    bool useWhitelist;
    string name;
    string twitter;
    string discord;
    string telegram;
    string website;
}

struct PreProject {
    address owner;
    address tokenIDO;
    address tokenUseToBuy;
    bool isRequireKyc;
    bool isRequireStake;
    bool isRequrieVesting;
    bool useWhitelist;
    string name;
    string twitter;
    string discord;
    string telegram;
    string website;
}

struct LaunchPool {
    VestingType typeVesting;
    uint256 tge;
    uint256 cliffTime;
    uint256 unlockPercent;
    uint256 linearTime;
    uint256[] time;
    uint256[] percent;
    uint256 tokenOffer;
    uint256 tokenPrice;
    uint256 totalRaise;
    uint256 ticketSize;
}

struct LaunchPad {
    VestingType typeVesting;
    uint256 tge;
    uint256 cliffTime;
    uint256 unlockPercent;
    uint256 linearTime;
    uint256[] time;
    uint256[] percent;
    uint256 tokenReward;
    uint256 totalAirdrop;
}

enum VestingType {
    VESTING_TYPE_MILESTONE_CLIFF_FIRST,
    VESTING_TYPE_MILESTONE_UNLOCK_FIRST,
    VESTING_TYPE_LINEAR_UNLOCK_FIRST,
    VESTING_TYPE_LINEAR_CLIFF_FIRST
}
