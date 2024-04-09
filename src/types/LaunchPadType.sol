// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library LaunchPad { }

struct ProjectProfile {
    string name;
    string twitter;
    string discord;
    string telegram;
    string website;
}

struct Order {
    address buyer;
    uint256 coinAmount;
    uint256 tokenAmount;
    uint256 tokenReleased;
}

struct LaunchPadState {
    RoundType round;
    uint64 participants;
    uint128 startTime;
    uint128 endTime;
    uint256 softCap;
    uint256 hardCap;
    uint256 totalTokenSold;
    uint256 swapRatioCoin;
    uint256 swapRatioToken;
    //when project stop fund-raising, to claim or refund
    // token_fund: Coin<TOKEN>,
    uint256 totalTokenDeposited;
    uint256 totalCoinedRaised;
    uint256 defaultMaxAllocate;
    RoundState state;
}
// coin_raised: Coin<COIN>,
// order_book: Table<address, Order>,
// uint256 default_max_allocate;
// max_allocations: Table<address, u64>,

struct Vesting {
    VestingType _type;
    uint256 tge;
    uint256 cliffTime;
    //cliff time duration in ms
    uint256 unlockPercent;
    //unlock percent scaled to x10
    uint256 linearTime;
    //linear vesting duration if linear mode
    uint256[] time;
    uint256[] percent;
}

struct Project {
    uint64 id;
    address owner;
    uint8 tokenIdoDeciamls;
    uint8 tokenDecimals;
    // address[] whitelist;
    address tokenIDO;
    address tokenUseToBuy;
    bool isRequireKyc;
    bool isRequireStake;
    bool isRequrieVesting;
    bool isByBuyNative;
    bool useWhitelist;
}
// FeeType feeType;
// ListType listType; // if manual : presale, privatesale, seed sale

struct SetUpProject {
    RoundType round;
    uint64 projectId;
    uint128 startTime;
    uint128 endTime;
    bool useWhitelist;
    uint256 swapRatioCoin;
    uint256 swapRatioToken;
    uint256 maxAllocate;
    uint256 softCap;
    uint256 hardCap;
}

enum RoundState {
    ROUND_STATE_INIT,
    ROUND_STATE_PREPARE,
    ROUND_STATE_RASING,
    ROUND_STATE_REFUNDING,
    ROUND_STATE_CLAIMING
}

enum VestingType {
    VESTING_TYPE_MILESTONE_CLIFF_FIRST,
    VESTING_TYPE_MILESTONE_UNLOCK_FIRST,
    VESTING_TYPE_LINEAR_UNLOCK_FIRST,
    VESTING_TYPE_LINEAR_CLIFF_FIRST
}

enum FeeType {
    FIX,
    PERCENT
}

enum ListType {
    Auto,
    Manual
}

enum RoundType {
    ROUND_NONE,
    ROUND_SEED,
    ROUND_PRIVATE,
    ROUND_PUBLIC
}
