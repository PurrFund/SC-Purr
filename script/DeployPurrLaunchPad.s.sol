// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseScript } from "./Base.s.sol";
import { PurrLaunchPad } from "../src/PurrLaunchPad.sol";
import { LaunchPool, LaunchPad, PreProject, VestingType } from "../src/types/PurrLaunchPadType.sol";
import { ERC20Mock } from "../test/mocks/ERC20Mock.sol";

contract DeployPurrLaunchPadScript is BaseScript {
    PreProject project;
    LaunchPool launchPool;
    LaunchPad launchPad;
    address usd = 0xcB269E7e42D8728C91CCF840c27A25f11285548f;
    uint64[] time;
    uint16[] percent;

    function run() public broadcast {
        time.push(uint64(block.timestamp + 45 days));
        time.push(uint64(block.timestamp + 90 days));
        time.push(uint64(block.timestamp + 120 days));
        percent.push(1000);
        percent.push(5000);
        percent.push(10_000);
        PurrLaunchPad launchpad = new PurrLaunchPad(msg.sender);
        ERC20Mock tokenIDO = new ERC20Mock("FANX", "FXK");

        project = PreProject({
            owner: msg.sender,
            tokenIDO: address(tokenIDO),
            name: "FANX",
            twitter: "twitter.com",
            discord: "discord.com",
            telegram: "telegram.com",
            website: "website.com"
        });

        launchPad = LaunchPad({
            unlockPercent: 1000,
            startTime: uint64(block.timestamp - 2 days),
            snapshotTime: uint64(block.timestamp + 2 days),
            autoVestingTime: uint64(block.timestamp + 3 days),
            vestingTime: uint64(block.timestamp + 7 days),
            percents: percent,
            times: time,
            tge: block.timestamp + 10 days,
            cliffTime: 30 days,
            linearTime: 50 days,
            tokenOffer: 100_000_000,
            tokenPrice: 100_000,
            totalRaise: 200_000,
            ticketSize: 300,
            typeVesting: VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST
        });

        launchPool = LaunchPool({
            unlockPercent: 1000,
            startTime: uint64(block.timestamp - 2 days),
            snapshotTime: uint64(block.timestamp + 2 days),
            autoVestingTime: uint64(block.timestamp + 3 days),
            vestingTime: uint64(block.timestamp + 7 days),
            percents: percent,
            times: time,
            tge: block.timestamp + 10 days,
            cliffTime: 30 days,
            linearTime: 50 days,
            tokenReward: 100_000_000,
            totalAirdrop: 20_000,
            typeVesting: VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST
        });

        launchpad.createProject(project, launchPool, launchPad);
    }
}
