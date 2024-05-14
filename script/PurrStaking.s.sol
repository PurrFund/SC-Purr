// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BaseScript } from "./Base.s.sol";
import { PurrStaking } from "../src/PurrStaking.sol";
import { PoolInfo, PoolType, TierType, TierInfo } from "../src/types/PurrStaingType.sol";

contract PurrStakingScript is BaseScript {
    address purrToken = 0x2C7468DF2836cE821C48867961556E62D76CA920;
    PurrStaking purrStaking;

    PoolInfo[] poolInfos;
    TierInfo[] tierInfos;
    // mock usd
    address usd = 0xdB4451f0e9b376F3b26EBE9fb676C9d827126F44;

    function run() public broadcast {
        _initPools();
        _initTiers();
        purrStaking = new PurrStaking(purrToken, msg.sender, poolInfos, tierInfos);
        ERC20(purrToken).approve(address(purrStaking), 1000e18);
        purrStaking.stake(100e18, PoolType.ONE);
        purrStaking.stake(100e18, PoolType.TWO);
        purrStaking.stake(100e18, PoolType.THREE);
        purrStaking.stake(100e18, PoolType.FOUR);
        purrStaking.unstake(10e18, 4);
    }

    function _initPools() internal {
        PoolInfo memory pool1 = PoolInfo({
            unstakeFee: 0,
            apy: 900,
            multiplier: 10,
            lockDay: 30 days,
            unstakeTime: 10 days,
            totalStaked: 0,
            numberStaker: 0,
            poolType: PoolType.ONE
        });
        PoolInfo memory pool2 = PoolInfo({
            unstakeFee: 1000,
            apy: 1200,
            multiplier: 15,
            lockDay: 60 days,
            unstakeTime: 0,
            totalStaked: 0,
            numberStaker: 0,
            poolType: PoolType.TWO
        });
        PoolInfo memory pool3 = PoolInfo({
            unstakeFee: 2000,
            apy: 1600,
            multiplier: 20,
            lockDay: 150 days,
            unstakeTime: 0,
            totalStaked: 0,
            numberStaker: 0,
            poolType: PoolType.THREE
        });
        PoolInfo memory pool4 = PoolInfo({
            unstakeFee: 3000,
            apy: 2100,
            multiplier: 25,
            lockDay: 240 days,
            unstakeTime: 0,
            totalStaked: 0,
            numberStaker: 0,
            poolType: PoolType.FOUR
        });
        poolInfos.push(pool1);
        poolInfos.push(pool2);
        poolInfos.push(pool3);
        poolInfos.push(pool4);
    }

    function _initTiers() internal {
        TierInfo memory tier1 = TierInfo({ lotteryProbabilities: 612, poolWeight: 1, pPoint: 1000, tierType: TierType.ONE });
        TierInfo memory tier2 = TierInfo({ lotteryProbabilities: 2534, poolWeight: 1, pPoint: 4000, tierType: TierType.TWO });
        TierInfo memory tier3 = TierInfo({ lotteryProbabilities: 5143, poolWeight: 1, pPoint: 10_000, tierType: TierType.THREE });
        TierInfo memory tier4 = TierInfo({ lotteryProbabilities: 7813, poolWeight: 2, pPoint: 30_000, tierType: TierType.FOUR });
        TierInfo memory tier5 = TierInfo({ lotteryProbabilities: 9553, poolWeight: 5, pPoint: 60_000, tierType: TierType.FIVE });
        TierInfo memory tier6 =
            TierInfo({ lotteryProbabilities: 10_000, poolWeight: 10, pPoint: 100_000, tierType: TierType.SIX });

        tierInfos.push(tier1);
        tierInfos.push(tier2);
        tierInfos.push(tier3);
        tierInfos.push(tier4);
        tierInfos.push(tier5);
        tierInfos.push(tier6);
    }
}
