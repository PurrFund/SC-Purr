// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseScript } from "./Base.s.sol";
import { MockUSDC } from "../src/token/MockUSDC.sol";

contract DeployMockUSDCScript is BaseScript {
    function run() public broadcast {
        new MockUSDC(msg.sender);
    }
}
