// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseTest } from "../Base.t.sol";
import { MockUSDC } from "../../src/token/MockUSDC.sol";
import { PurrDeposit } from "../../src/PurrDeposit.sol";

contract PurrLaunchPadTest is BaseTest {
    PurrDeposit public purrDeposit;
    MockUSDC public tokenPurr;

    event Deposit(address indexed depositor, address indexed receiver, uint256 amount, uint256 timeDeposit);

    function setUp() public {
        tokenPurr = new MockUSDC(users.admin);
        purrDeposit = new PurrDeposit(users.admin, address(tokenPurr), users.admin, users.alice);
    }

    function test_ShouldRevert_Amount_Deposit() public {
        bytes4 selector = bytes4(keccak256("InvalidAmount(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 0));

        vm.prank(users.alice);
        purrDeposit.deposit(0);
    }

    function test_ShouldRevert_AmountAllowance_Deposit() public {
        bytes4 selector = bytes4(keccak256("InsufficientAllowance()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.alice);
        purrDeposit.deposit(20);
    }

    function _deal(address _reciever, uint256 _amount) internal {
        vm.prank(users.admin);
        tokenPurr.mint(_reciever, _amount);
    }

    function test_Expect_Deposit() public {
        uint256 oldBallanceAmin = tokenPurr.balanceOf(users.admin);
        _deal(users.alice, 30);
        vm.startPrank(users.alice);
        tokenPurr.approve(address(purrDeposit), 30);
        purrDeposit.deposit(20);
        vm.stopPrank();
        uint256 newBallanceAmin = tokenPurr.balanceOf(users.admin);
        uint256 depositAmount = newBallanceAmin - oldBallanceAmin;
        vm.assertEq(depositAmount, 20);
    }

    function test_EmitEvent_Deposit() public {
        _deal(users.alice, 30);
        vm.startPrank(users.alice);
        tokenPurr.approve(address(purrDeposit), 30);
        vm.expectEmit(true, true, true, true);
        emit Deposit(users.alice, address(purrDeposit), 20, block.timestamp);
        purrDeposit.deposit(20);
        vm.stopPrank();
    }
}
