// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseScript } from "./Base.s.sol";
import { MockUSD } from "../test/mocks/MockUSD.sol";

contract DeployMockUSDScript is BaseScript {
    function run() public broadcast {
        new MockUSD(msg.sender);
    }
}
