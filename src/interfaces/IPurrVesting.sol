// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PoolState, Pool } from "../types/PurrVestingType.sol";

interface IPurrVesting {
    // event list
    event CreatePoolEvent(uint256 poolId, Pool pool);
    event AddFundEvent(uint256 poolId, address[] user, uint256[] fundAmount);
    event RemoveFundEvent(uint256 poolId, address[] user);
    event ClaimFundEvent(uint256 poolId, address user, uint256 fundClaimed);

    // error list
    error InvalidState(PoolState state);
    error InvalidArgument();
    error InvalidTime(uint256 timestamp);
    error InvalidClaimPercent();
    error InvalidClaimAmount();
    error InvalidFund();
    error InvalidVestingType();
    error InvalidArgCreatePool();
    error InvalidPoolIndex(uint256 poolId); 
    error InvalidClaimer(address claimer); 
}