// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseTest } from "../../Base.t.sol";
import { PurrDeposit } from "../../../src/PurrDeposit.sol";
import { IBEP20 } from "../../../src/interfaces/IBEP20.sol";

contract ForkPurrDeposit is BaseTest {
    uint256 fork;
    uint32 networkId;
    IBEP20 usdc;
    IBEP20 _usdc;
    PurrDeposit purrDeposit;
    address[] depositorAddresses;
    uint256[] amounts;

    modifier setFork(uint256 _fork) {
        vm.selectFork(_fork);
        _;
    }

    event Deposit(address indexed receiver, uint256 amount, uint256 timeDeposit);
    event WithDrawRootAdmin(address indexed sender, address indexed receiver, uint256 amount);
    event UpdatePoolDeposit(bool canWithDrawAndDeposit);
    event WithDrawUser(address indexed sender, uint256 amount, uint256 timeWithDraw);
    event UpdateBalanceDepositor();
    event SetUsd(address usd);
    event AddFund(address indexed admin, address indexed receiver, uint256 amount);

    function setUp() public {
        fork = vm.createFork(vm.envString("L1_RPC_URL"));

        usdc = IBEP20(vm.envAddress("ADDRESS_L1_USDC"));
        _usdc = IBEP20(vm.envAddress("ADDRESS_L1_USDC2"));

        vm.selectFork(fork);
        deal(address(usdc), users.alice, 1000 * 1e18);
        deal(address(usdc), users.admin, 1000 * 1e18);

        vm.startPrank(users.admin);
        vm.selectFork(fork);
        purrDeposit = new PurrDeposit(users.admin, address(usdc), users.rootAdmin, users.subAdmin);
        vm.stopPrank();
    }

    function test_Deploy_ShouldRight_InitialOwner() public setFork(fork) {
        assertEq(users.admin, purrDeposit.owner());
    }

    function test_Deploy_ShouldRight_RootAdmin() public setFork(fork) {
        assertEq(users.rootAdmin, purrDeposit.rootAdmin());
    }

    function test_Deploy_ShouldRight_SubAdmin() public setFork(fork) {
        assertEq(users.subAdmin, purrDeposit.subAdmin());
    }

    function test_Deploy_ShouldRight_CanWithDrawAndDeposit() public setFork(fork) {
        assertEq(true, purrDeposit.canWithDrawAndDeposit());
    }

    function test_Deploy_ShouldRight_Usd() public setFork(fork) {
        assertEq(address(usdc), address(purrDeposit.usd()));
    }

    function test_Deposit_ShouldRevert_WhenInvalidAmount() public setFork(fork) {
        bytes4 selector = bytes4(keccak256("InvalidAmount(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 0));

        vm.prank(users.alice);
        purrDeposit.deposit(0);
    }

    function test_Deposit_ShouldRevert_WhenInsufficientAllowance() public setFork(fork) {
        vm.expectRevert("BEP20: transfer amount exceeds allowance");

        vm.prank(users.alice);
        purrDeposit.deposit(20);
    }

    function test_Deposit_ShouldDeposited() public setFork(fork) {
        uint256 prePurrBL = usdc.balanceOf(address(purrDeposit));
        uint256 preAliceBL = usdc.balanceOf(users.alice);
        uint256 preAliceBLPurr = purrDeposit.depositorInfo(users.alice);
        uint256 amountDeposit = 10e18;

        vm.startPrank(users.alice);
        usdc.approve(address(purrDeposit), amountDeposit);
        purrDeposit.deposit(amountDeposit);
        vm.stopPrank();

        uint256 posPurrBL = usdc.balanceOf(address(purrDeposit));
        uint256 posAliceBL = usdc.balanceOf(users.alice);
        uint256 posAliceBLPurr = purrDeposit.depositorInfo(users.alice);

        assertEq(prePurrBL + amountDeposit, posPurrBL);
        assertEq(preAliceBL - amountDeposit, posAliceBL);
        assertEq(preAliceBLPurr + amountDeposit, posAliceBLPurr);
    }

    function test_Deposit_ShouldEmit_EventDeposit() public setFork(fork) {
        uint256 amountDeposit = 10e18;
        vm.prank(users.alice);
        usdc.approve(address(purrDeposit), amountDeposit);

        vm.expectEmit(true, true, true, true);
        emit Deposit(users.alice, amountDeposit, block.timestamp);

        vm.prank(users.alice);
        purrDeposit.deposit(amountDeposit);
    }

    function test_AddFund_ShouldRevert_WhenInvalidAmount() public setFork(fork) {
        bytes4 selector = bytes4(keccak256("InvalidAmount(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 0));

        vm.prank(users.alice);
        purrDeposit.deposit(0);
    }

    function test_AddFund_ShouldAddFunded() public setFork(fork) {
        uint256 amount = 100e18;
        uint256 prePurrDepositBL = usdc.balanceOf(address(purrDeposit));
        uint256 preAliceBL = usdc.balanceOf(users.alice);

        vm.startPrank(users.alice);
        usdc.approve(address(purrDeposit), amount);
        purrDeposit.addFund(amount);
        vm.stopPrank();

        uint256 posPurrDepositBL = usdc.balanceOf(address(purrDeposit));
        uint256 posAliceBL = usdc.balanceOf(users.alice);

        assertEq(prePurrDepositBL + amount, posPurrDepositBL);
        assertEq(preAliceBL - amount, posAliceBL);
    }

    function test_AddFund_ShouldEmit_EventAddFund() public setFork(fork) {
        uint256 amount = 100e18;

        vm.prank(users.alice);
        usdc.approve(address(purrDeposit), amount);

        vm.expectEmit(true, true, true, true);
        emit AddFund(users.alice, address(purrDeposit), amount);

        vm.prank(users.alice);
        purrDeposit.addFund(amount);
    }

    function test_WithDrawRootAdmin_ShouldRevert_WhenNotRootAdmin() public setFork(fork) {
        bytes4 selector = bytes4(keccak256("InvalidRootAdmin(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrDeposit.withDrawRootAdmin(0);
    }

    function test_WithDrawRootAdmin_ShouldRevert_WhenInvalidAmount() public setFork(fork) {
        bytes4 selector = bytes4(keccak256("InvalidAmount(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 0));

        vm.prank(users.rootAdmin);
        purrDeposit.withDrawRootAdmin(0);
    }

    function test_WithDrawRootAdmin_ShouldWithDrawRootAdmined() public setFork(fork) {
        uint256 amount = 100e18;
        uint256 withDrawAmount = 70e18;

        vm.startPrank(users.alice);
        usdc.approve(address(purrDeposit), amount);
        purrDeposit.addFund(amount);
        vm.stopPrank();

        uint256 prePurrBL = usdc.balanceOf(address(purrDeposit));
        uint256 preRootAdminBL = usdc.balanceOf(users.rootAdmin);

        vm.startPrank(users.rootAdmin);
        purrDeposit.withDrawRootAdmin(withDrawAmount);
        vm.stopPrank();

        uint256 posPurrBL = usdc.balanceOf(address(purrDeposit));
        uint256 posRootAdminBL = usdc.balanceOf(users.rootAdmin);

        assertEq(prePurrBL - withDrawAmount, posPurrBL);
        assertEq(preRootAdminBL + withDrawAmount, posRootAdminBL);
    }

    function test_WithDrawRootAdmin_ShouldEmit_EventwithDrawRootAdmin() public setFork(fork) {
        uint256 amount = 100e18;
        uint256 withDrawAmount = 70e18;

        vm.startPrank(users.alice);
        usdc.approve(address(purrDeposit), amount);
        purrDeposit.addFund(amount);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit WithDrawRootAdmin(address(purrDeposit), users.rootAdmin, withDrawAmount);

        vm.startPrank(users.rootAdmin);
        purrDeposit.withDrawRootAdmin(withDrawAmount);
        vm.stopPrank();
    }

    function test_WithDrawUser_ShouldReVert_WhenCanNotWithDraw() public setFork(fork) {
        vm.prank(users.admin);
        purrDeposit.updateStatusWithDrawAndDeposit(false);

        bytes4 selector = bytes4(keccak256("CanNotWithDraw()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.alice);
        purrDeposit.withDrawUser(20);
    }

    function test_WithDrawUser_ShouldRevert_WhenInvalidAmount() public setFork(fork) {
        bytes4 selector = bytes4(keccak256("InvalidAmount(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 0));

        vm.prank(users.alice);
        purrDeposit.withDrawUser(0);
    }

    function test_WithDrawUser_ShouldRevert_WhenInsufficientTotalSupply() public setFork(fork) {
        uint256 amountAddFund = 100e18;
        uint256 amountDeposit = 100e18;
        uint256 amountWithDraw = 220e18;

        vm.startPrank(users.admin);
        usdc.approve(address(purrDeposit), amountAddFund);
        purrDeposit.addFund(amountAddFund);
        vm.stopPrank();

        vm.startPrank(users.alice);
        usdc.approve(address(purrDeposit), amountDeposit);
        purrDeposit.addFund(amountDeposit);
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("InsufficientTotalSupply(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, amountWithDraw));

        vm.prank(users.alice);
        purrDeposit.withDrawUser(amountWithDraw);
    }

    function test_WithDrawUser_ShouldRevert_WhenInsufficientBalance() public setFork(fork) {
        uint256 amountAddFund = 300e18;
        uint256 amountDeposit = 100e18;
        uint256 amountWithDraw = 200e18;

        vm.startPrank(users.admin);
        usdc.approve(address(purrDeposit), amountAddFund);
        purrDeposit.addFund(amountAddFund);
        vm.stopPrank();

        vm.startPrank(users.alice);
        usdc.approve(address(purrDeposit), amountDeposit);
        purrDeposit.deposit(amountDeposit);
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("InsufficientBalance(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, amountWithDraw));

        vm.prank(users.alice);
        purrDeposit.withDrawUser(amountWithDraw);
    }

    function test_WithDrawUser_ShouldWithDrawUsered() public setFork(fork) {
        uint256 amountAddFund = 300e18;
        uint256 amountDeposit = 100e18;
        uint256 amountWithDraw = 50e18;

        vm.startPrank(users.admin);
        usdc.approve(address(purrDeposit), amountAddFund);
        purrDeposit.addFund(amountAddFund);
        vm.stopPrank();

        vm.startPrank(users.alice);
        usdc.approve(address(purrDeposit), amountDeposit);
        purrDeposit.deposit(amountDeposit);
        vm.stopPrank();

        uint256 preBalanceAlice = usdc.balanceOf(users.alice);

        vm.prank(users.alice);
        purrDeposit.withDrawUser(amountWithDraw);

        uint256 posBalanceAlice = usdc.balanceOf(users.alice);
        uint256 posBalancePurrDeposit = usdc.balanceOf(address(purrDeposit));

        assertEq(purrDeposit.depositorInfo(users.alice), amountDeposit - amountWithDraw);
        assertEq(posBalanceAlice - preBalanceAlice, amountDeposit - amountWithDraw);
        assertEq(posBalancePurrDeposit, amountAddFund + amountDeposit - amountWithDraw);
    }

    function test_WithDrawUser_ShouldEmit_EventWithDrawUser() public setFork(fork) {
        uint256 amountAddFund = 300e18;
        uint256 amountDeposit = 100e18;
        uint256 amountWithDraw = 50e18;

        vm.startPrank(users.admin);
        usdc.approve(address(purrDeposit), amountAddFund);
        purrDeposit.addFund(amountAddFund);
        vm.stopPrank();

        vm.startPrank(users.alice);
        usdc.approve(address(purrDeposit), amountDeposit);
        purrDeposit.deposit(amountDeposit);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit WithDrawUser(users.alice, amountWithDraw, block.timestamp);

        vm.prank(users.alice);
        purrDeposit.withDrawUser(amountWithDraw);
    }

    function test_UpdateBalanceDepositor_ShouldRevert_WhenNotOwner() public setFork(fork) {
        depositorAddresses.push(address(1));
        amounts.push(10);

        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrDeposit.updateBalanceDepositor(depositorAddresses, amounts);
    }

    function test_UpdateBalanceDepositor_ShouldRevert_InvalidArgument() public setFork(fork) {
        depositorAddresses.push(address(1));
        amounts.push(10);
        amounts.push(20);

        bytes4 selector = bytes4(keccak256("InvalidArgument()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrDeposit.updateBalanceDepositor(depositorAddresses, amounts);
    }

    function test_UpdateBalanceDepositor_ShouldUpdateBalanceDepositored() public setFork(fork) {
        uint256 length = 100;

        for (uint256 i; i < length;) {
            address iAddress = vm.addr(i + 1);
            deal(address(usdc), iAddress, i + 1);
            depositorAddresses.push(address(iAddress));
            amounts.push(i);
            vm.startPrank(iAddress);
            usdc.approve(address(purrDeposit), i + 1);
            purrDeposit.deposit(i + 1);
            vm.stopPrank();
            unchecked {
                ++i;
            }
        }

        vm.prank(users.admin);
        purrDeposit.updateBalanceDepositor(depositorAddresses, amounts);

        uint256 depositLength = depositorAddresses.length;
        for (uint256 i; i < depositLength; ++i) {
            assertEq(purrDeposit.depositorInfo(depositorAddresses[i]), amounts[i]);
        }
    }

    function test_TurnOffWithDraw_ShouldRevert_NotSubAdmin() public setFork(fork) {
        bytes4 selector = bytes4(keccak256("InvalidSubAdmin(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrDeposit.turnOffWithDrawAndDeposit();
    }

    function test_TurnOffWithDraw_ShouldTurnOffWithDrawed() public setFork(fork) {
        vm.prank(users.subAdmin);
        purrDeposit.turnOffWithDrawAndDeposit();

        assertEq(purrDeposit.canWithDrawAndDeposit(), false);
    }

    function test_UpdateStatusWithDraw_ShouldRevert_WhenNotOwner() public setFork(fork) {
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrDeposit.updateStatusWithDrawAndDeposit(false);
    }

    function test_UpdateStatusWithDraw_ShouldUpdateStatusWithDrawed() public setFork(fork) {
        vm.prank(users.admin);
        purrDeposit.updateStatusWithDrawAndDeposit(false);

        assertEq(purrDeposit.canWithDrawAndDeposit(), false);
    }

    function test_SetUsd_ShouldRevert_NotOwner() public setFork(fork) {
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrDeposit.setUsd(address(_usdc));
    }

    function test_SetUsd_ShouldSetUsd() public setFork(fork) {
        vm.prank(users.admin);
        purrDeposit.setUsd(address(_usdc));

        assertEq(address(purrDeposit.usd()), address(_usdc));
    }

    function test_SetRootAdmin_ShouldRevert_WhenNotRootAdmin() public setFork(fork) {
        bytes4 selector = bytes4(keccak256("InvalidRootAdmin(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrDeposit.setRootAdmin(users.alice);
    }

    function test_SetRootAdmin_ShouldSetRootAdmined() public setFork(fork) {
        vm.prank(users.rootAdmin);
        purrDeposit.setRootAdmin(users.alice);

        assertEq(users.alice, purrDeposit.rootAdmin());
    }

    function test_SetSubAdmin_ShouldRevert_WhenNotOwner() public setFork(fork) {
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrDeposit.setSubAdmin(users.alice);
    }

    function test_SetSubAdmin_ShouldSetSubAdmined() public setFork(fork) {
        vm.prank(users.rootAdmin);
        purrDeposit.setSubAdmin(users.rootAdmin);

        assertEq(users.rootAdmin, purrDeposit.subAdmin());
    }

    function test_TransferOwnership_ShouldRevert_WhenNotRootAdminAndOwner() public setFork(fork) {
        bytes4 selector1 = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector1, users.alice));

        vm.prank(users.alice);
        purrDeposit.transferOwnership(users.alice);

        bytes4 selector2 = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector2, users.subAdmin));

        vm.prank(users.subAdmin);
        purrDeposit.transferOwnership(users.subAdmin);
    }

    function test_TransferOwnership_ShouldTransferOwnershiped() public setFork(fork) {
        vm.prank(users.admin);
        purrDeposit.transferOwnership(users.alice);

        assertEq(purrDeposit.owner(), users.alice);

        vm.prank(users.rootAdmin);
        purrDeposit.transferOwnership(users.bob);

        assertEq(purrDeposit.owner(), users.bob);

        vm.prank(users.bob);
        purrDeposit.updateStatusWithDrawAndDeposit(true);

        assertEq(purrDeposit.canWithDrawAndDeposit(), true);
    }
}
