// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseScript } from "./Base.s.sol";
import { PurrToken } from "../src/token/PurrToken.sol";

contract DeployPurrTokenScript is BaseScript {
    PurrToken purr;

    function run() public broadcast {
        purr = new PurrToken(msg.sender, "PurrToken", "PLT");

        purr.mint(msg.sender, 100_000e18);
    }
}
