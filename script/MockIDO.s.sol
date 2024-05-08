// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseScript } from "./Base.s.sol";
import { ERC20Mock } from "../test/mocks/ERC20Mock.sol";

contract DeployIDOMOCKScript is BaseScript {
    function run() public broadcast {
        new ERC20Mock("SAKA", "SKT");
    }
}
