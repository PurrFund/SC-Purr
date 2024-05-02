// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BaseScript } from "./Base.s.sol";
import { PurrToken } from "../src/token/PurrToken.sol";

contract DeployPurrTokenScript is BaseScript {
    PurrToken purr; 

    function run() public broadcast {
        purr = new PurrToken(msg.sender, "PurrToken","PLT" );
        
        purr.mint(msg.sender, 100000e18);
    }
}
