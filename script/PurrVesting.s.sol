// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BaseScript } from "./Base.s.sol";
import { PurrVesting } from "../src/PurrVesting.sol";
import { CreatePool, VestingType, PoolState } from "../src/types/PurrVestingType.sol";

contract PurrVestingScript is BaseScript {
    PurrVesting purrVesting;
    address idoMock = 0x9ab93Fe22e82dC098dA674818a74901EB7a9D7A6;
    uint64[] times;
    uint16[] percents;
    uint256[] fundAmounts;
    address[] users;

    function run() public broadcast {
        purrVesting = new PurrVesting(msg.sender);
        CreatePool memory createPool1 = CreatePool({
            tokenFund: idoMock,
            name: "FANX",
            vestingType: VestingType.VESTING_TYPE_LINEAR_CLIFF_FIRST,
            tge: block.timestamp + 1 days,
            cliff: block.timestamp + 2 days,
            unlockPercent: 1000,
            linearVestingDuration: 365 days,
            times: times,
            percents: percents
        });

        purrVesting.createPool(createPool1);

        ERC20(idoMock).approve(address(purrVesting), 10_000_000_000_000_000_000_000_000);

        users.push(address(1));
        users.push(address(2));
        users.push(address(3));
        fundAmounts.push(100e18);
        fundAmounts.push(150e18);
        fundAmounts.push(120e18);

        purrVesting.addFund(1, fundAmounts, users);
    }
}
