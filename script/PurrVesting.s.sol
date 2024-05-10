// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BaseScript } from "./Base.s.sol";
import { PurrVesting } from "../src/PurrVesting.sol";
import { CreatePool, VestingType } from "../src/types/PurrVestingType.sol";

contract PurrVestingScript is BaseScript {
    PurrVesting purrVesting;
    address idoMock = 0x9ab93Fe22e82dC098dA674818a74901EB7a9D7A6;
    uint64[] times;
    uint16[] percents;
    uint256[] fundAmountList;
    address[] userList;

    function run() public broadcast {
        purrVesting = new PurrVesting(msg.sender);
        CreatePool memory createPool1 = CreatePool({
            projectId: "17aa0f02-6ce1-4352-84ab-42bc0fa66d15",
            tokenFund: idoMock,
            name: "FANX",
            vestingType: VestingType.VESTING_TYPE_LINEAR_CLIFF_FIRST,
            tge: block.timestamp + 10 seconds,
            cliff: 10 seconds,
            unlockPercent: 1000,
            linearVestingDuration: 365 days,
            times: times,
            percents: percents
        });

        purrVesting.createPool(createPool1);

        ERC20(idoMock).approve(address(purrVesting), ERC20(idoMock).balanceOf(msg.sender));

        userList.push(0x9C623EfF30c8BCba288fc0346C44576d3c7FF52C);
        userList.push(0x1405dC6c6cB6Cb9480F01E3E43a5ec89f680Cb8D);
        userList.push(0xA9c80A4ece07EAcA61E20c79c7D4DE343A6A3d27);
        fundAmountList.push(100e18);
        fundAmountList.push(150e18);
        fundAmountList.push(120e18);

        purrVesting.addFund(1, fundAmountList, userList);
        purrVesting.start(1);
    }

    // function claim(address _purrVesting, address _user) public broadcastCustom(_user){
    //     uint256 poolId = 1;
    //     PurrVesting(_purrVesting).claimFund(_poolId);
    // }
}
