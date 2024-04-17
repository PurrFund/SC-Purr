// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseScript } from "./Base.s.sol";
import { PurrDeposit } from "../src/PurrDeposit.sol";

contract DeployPurrDepositScript is BaseScript {
    address rootAdmin = vm.envAddress("ROOT_ADMIN");
    address subAdmin = vm.envAddress("SUB_ADMIN");
    // mock usdc
    address usdc = 0xcB269E7e42D8728C91CCF840c27A25f11285548f;

    function run() public broadcast {
        new PurrDeposit(msg.sender, usdc, rootAdmin, subAdmin);
    }
}
