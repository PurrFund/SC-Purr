// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct UserPower {
    Power power;
    uint256 balance;
}

struct PowerSystem {
    uint256 weight;
    uint256 amount;
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
