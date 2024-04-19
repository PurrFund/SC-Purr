// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseTest } from "../Base.t.sol";
import { MockUSD } from "../../test/mocks/MockUSD.sol";
import { PurrDeposit } from "../../src/PurrDeposit.sol";

contract PurrDepositTest is BaseTest {
    PurrDeposit public purrDeposit;

    event Deposit(address indexed depositor, address indexed receiver, uint256 amount, uint256 timeDeposit);
    event WithDrawRootAdmin(address indexed sender, address indexed receiver, uint256 amount);

    function setUp() public {
        usd = new MockUSD(users.admin);
        purrDeposit = new PurrDeposit(users.admin, address(usd), users.rootAdmin, users.subAdmin);

        _deal(users.alice, 1000e18);
        _deal(users.admin, 1000e18);
        _deal(users.bob, 1000e18);
    }

    function test_Deploy_ShouldRight_InitialOwner() public view {
        assertEq(users.admin, purrDeposit.owner());
    }

    function test_Deploy_ShouldRight_RootAdmin() public view {
        assertEq(users.rootAdmin, purrDeposit.rootAdmin());
    }

    function test_Deploy_ShouldRight_SubAdmin() public view {
        assertEq(users.subAdmin, purrDeposit.subAdmin());
    }

    function test_Deploy_ShouldRight_CanWithDraw() public view {
        assertEq(true, purrDeposit.canWithDraw());
    }

    function test_Deploy_ShouldRight_Usd() public view {
        assertEq(address(usd), address(purrDeposit.usd()));
    }

    function test_Deposit_ShouldRevert_WhenInvalidAmount() public {
        bytes4 selector = bytes4(keccak256("InvalidAmount(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 0));

        vm.prank(users.alice);
        purrDeposit.deposit(0);
    }

    function test_Deposit_ShouldRevert_WhenInsufficientAllowance() public {
        bytes4 selector = bytes4(keccak256("ERC20InsufficientAllowance(address,uint256,uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, address(purrDeposit), 0, 20));

        vm.prank(users.alice);
        purrDeposit.deposit(20);
    }

    function test_Deposit_ShouldDeposited() public {
        uint256 prePurrBL = usd.balanceOf(address(purrDeposit));
        uint256 preAliceBL = usd.balanceOf(users.alice);
        uint256 preAliceBLPurr = purrDeposit.depositorInfo(users.alice);
        uint256 amountDeposit = 10e18;

        vm.startPrank(users.alice);
        usd.approve(address(purrDeposit), amountDeposit);
        purrDeposit.deposit(amountDeposit);
        vm.stopPrank();

        uint256 posPurrBL = usd.balanceOf(address(purrDeposit));
        uint256 posAliceBL = usd.balanceOf(users.alice);
        uint256 posAliceBLPurr = purrDeposit.depositorInfo(users.alice);

        assertEq(prePurrBL + amountDeposit, posPurrBL);
        assertEq(preAliceBL - amountDeposit, posAliceBL);
        assertEq(preAliceBLPurr + amountDeposit, posAliceBLPurr);
    }

    function test_Deposit_ShouldEmit_EventDeposit() public {
        uint256 amountDeposit = 10e18;
        vm.prank(users.alice);
        usd.approve(address(purrDeposit), amountDeposit);

        vm.expectEmit(true, true, true, true);
        emit Deposit(users.alice, address(purrDeposit), amountDeposit, block.timestamp);

        vm.prank(users.alice);
        purrDeposit.deposit(amountDeposit);
    }

    function test_AddFund_ShouldRevert_WhenInvalidAmount() public {
        bytes4 selector = bytes4(keccak256("InvalidAmount(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 0));

        vm.prank(users.alice);
        purrDeposit.deposit(0);
    }

    function test_AddFund_ShouldAddFunded() public {
        uint256 amount = 100e18;
        uint256 prePurrDepositBL = usd.balanceOf(address(purrDeposit));
        uint256 preAliceBL = usd.balanceOf(users.alice);

        vm.startPrank(users.alice);
        usd.approve(address(purrDeposit), amount);
        purrDeposit.addFund(amount);
        vm.stopPrank();

        uint256 posPurrDepositBL = usd.balanceOf(address(purrDeposit));
        uint256 posAliceBL = usd.balanceOf(users.alice);

        assertEq(prePurrDepositBL + amount, posPurrDepositBL);
        assertEq(preAliceBL - amount, posAliceBL);
    }

    function test_WithDrawRootAdmin_ShouldRevert_WhenNotRootAdmin() public {
        bytes4 selector = bytes4(keccak256("InvalidRootAdmin(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrDeposit.withDrawRootAdmin(0);
    }

    function test_WithDrawRootAdmin_ShouldRevert_WhenInvalidAmount() public {
        bytes4 selector = bytes4(keccak256("InvalidAmount(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 0));

        vm.prank(users.rootAdmin);
        purrDeposit.withDrawRootAdmin(0);
    }

    function test_WithDrawRootAdmin_ShouldWithDrawRootAdmined() public {
        uint256 amount = 100e18;
        uint256 withDrawAmount = 70e18;

        vm.startPrank(users.alice);
        usd.approve(address(purrDeposit), amount);
        purrDeposit.addFund(amount);
        vm.stopPrank();

        uint256 prePurrBL = usd.balanceOf(address(purrDeposit));
        uint256 preRootAdminBL = usd.balanceOf(users.rootAdmin);

        vm.startPrank(users.rootAdmin);
        purrDeposit.withDrawRootAdmin(withDrawAmount);
        vm.stopPrank();

        uint256 posPurrBL = usd.balanceOf(address(purrDeposit));
        uint256 posRootAdminBL = usd.balanceOf(users.rootAdmin);

        assertEq(prePurrBL - withDrawAmount, posPurrBL);
        assertEq(preRootAdminBL + withDrawAmount, posRootAdminBL);
    }

    function test_WithDrawRootAdmin_ShouldEmit_EventwithDrawRootAdmin() public {
        uint256 amount = 100e18;
        uint256 withDrawAmount = 70e18;

        vm.startPrank(users.alice);
        usd.approve(address(purrDeposit), amount);
        purrDeposit.addFund(amount);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit WithDrawRootAdmin(address(purrDeposit), users.rootAdmin, withDrawAmount);

        vm.startPrank(users.rootAdmin);
        purrDeposit.withDrawRootAdmin(withDrawAmount);
        vm.stopPrank();
    }

    function test_WithDrawUser_ShouldReVert_WhenCanNotWithDraw() public { }

    function test_WithDrawUser_ShouldRevert_WhenInvalidAmount() public { }

    function test_WithDrawUser_ShouldRevert_WhenInsufficientTotalSupply() public { }

    function test_WithDrawUser_ShouldRevert_WhenInsufficientBalance() public { }

    function test_WithDrawUser_ShouldWithDrawUsered() public { }

    function test_WithDrawUser_ShouldEmit_EventWithDrawUser() public { }

    function _deal(address _reciever, uint256 _amount) internal {
        vm.prank(users.admin);
        usd.mint(_reciever, _amount);
    }
}
