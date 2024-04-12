// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseScript } from "./Base.s.sol";
import { PurrLaunchPad } from "../src/PurrLaunchPad.sol";
import { LaunchPool, LaunchPad, PreProject, VestingType } from "../src/types/LaunchPadType.sol";
import { ERC20Mock } from "../test/mocks/ERC20Mock.sol";

contract DeployPurrLaunchPadScript is BaseScript {
    PreProject project;
    LaunchPool launchPool;
    LaunchPad launchPad;
    address usdc = 0xcB269E7e42D8728C91CCF840c27A25f11285548f;
    uint256[] time;
    uint256[] percent;

    function run() public broadcast {
        time.push(block.timestamp + 45 days);
        time.push(block.timestamp + 90 days);
        time.push(block.timestamp + 120 days);
        percent.push(1000);
        percent.push(5000);
        percent.push(10_000);
        PurrLaunchPad launchpad = new PurrLaunchPad(msg.sender);
        ERC20Mock tokenIDO = new ERC20Mock("FANX", "FXK");
        project = PreProject({
            owner: msg.sender,
            tokenIDO: address(tokenIDO),
            tokenUseToBuy: usdc,
            isRequireKyc: true,
            isRequireStake: true,
            isRequrieVesting: true,
            useWhitelist: true,
            name: "FANX",
            twitter: "twitter.com",
            discord: "discord.com",
            telegram: "telegram.com",
            website: "website.com"
        });
        launchPool = LaunchPool({
            typeVesting: VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST,
            tge: block.timestamp + 10 days,
            cliffTime: 30 days,
            unlockPercent: 1000,
            linearTime: 50 days,
            time: time,
            percent: percent,
            tokenOffer: 100_000_000,
            tokenPrice: 100_000,
            totalRaise: 200_000,
            ticketSize: 300
        });

        launchPad = LaunchPad({
            typeVesting: VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST,
            tge: block.timestamp + 10 days,
            cliffTime: 30 days,
            unlockPercent: 1000,
            linearTime: 50 days,
            time: time,
            percent: percent,
            tokenReward: 100_000_000,
            totalAirdrop: 20_000
        });

        launchpad.createProject(project, launchPool, launchPad);
    }
}
