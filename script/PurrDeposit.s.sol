// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { BaseScript } from "./Base.s.sol";
import { PurrDeposit } from "../src/PurrDeposit.sol";

contract PurrDepositScript is BaseScript {
    address rootAdmin = vm.envAddress("ROOT_ADMIN");
    address subAdmin = vm.envAddress("SUB_ADMIN");
    PurrDeposit purr;
    // mock usd
    address usd = 0xdB4451f0e9b376F3b26EBE9fb676C9d827126F44;

    function run() public broadcast {
        purr = new PurrDeposit(msg.sender, usd, rootAdmin, subAdmin);
        ERC20(usd).approve(address(purr), 10_000e18);
        purr.deposit(10_000e18);
        purr.withDrawUser(100e18);
    }

    function deposit(address _sender, uint256 _amount) public {
        vm.startBroadcast(_sender);
        address _purr = 0x7808FA36E63c8832560876eC934B46D35d090a85;
        ERC20(usd).approve(_purr, _amount);
        PurrDeposit(_purr).deposit(_amount);
        vm.stopBroadcast();
    }
}
