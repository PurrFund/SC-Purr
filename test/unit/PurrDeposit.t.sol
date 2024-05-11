// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseTest } from "../Base.t.sol";
import { MockUSD } from "../../test/mocks/MockUSD.sol";
import { PurrDeposit } from "../../src/PurrDeposit.sol";

contract PurrDepositTest is BaseTest {
    PurrDeposit public purrDeposit;
    address[] depositorAddresses;
    uint256[] amounts;

    event Deposit(address indexed receiver, uint256 amount, uint256 timeDeposit);
    event WithDrawRootAdmin(address indexed sender, address indexed receiver, uint256 amount);
    event UpdatePoolDeposit(bool canWithDrawAndDeposit);
    event WithDrawUser(address indexed sender, uint256 amount, uint256 timeWithDraw);
    event UpdateBalanceDepositor();
    event SetUsd(address usd);
    event AddFund(address indexed admin, address indexed receiver, uint256 amount);

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

    function test_Deploy_ShouldRight_CanWithDrawAndDeposit() public view {
        assertEq(true, purrDeposit.canWithDrawAndDeposit());
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

    function test_Deposit_ShouldRevert_WhenCanNotDeposit() public {
        vm.startPrank(users.subAdmin);
        purrDeposit.turnOffWithDrawAndDeposit();

        uint256 amountDeposit = 10e18;

        vm.startPrank(users.alice);
        usd.approve(address(purrDeposit), amountDeposit);
        bytes4 selector = bytes4(keccak256("CanNotDeposit()"));
        vm.expectRevert(abi.encodeWithSelector(selector));
        purrDeposit.deposit(amountDeposit);
        vm.stopPrank();
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
        assertEq(purrDeposit.totalDeposit(), amountDeposit);
    }

    function test_Deposit_ShouldEmit_EventDeposit() public {
        uint256 amountDeposit = 10e18;
        vm.prank(users.alice);
        usd.approve(address(purrDeposit), amountDeposit);

        vm.expectEmit(true, true, true, true);
        emit Deposit(users.alice, amountDeposit, block.timestamp);

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

    function test_AddFund_ShouldEmit_EventAddFund() public {
        uint256 amount = 100e18;

        vm.prank(users.alice);
        usd.approve(address(purrDeposit), amount);

        vm.expectEmit(true, true, true, true);
        emit AddFund(users.alice, address(purrDeposit), amount);

        vm.prank(users.alice);
        purrDeposit.addFund(amount);
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

    function test_WithDrawUser_ShouldReVert_WhenCanNotWithDraw() public {
        vm.prank(users.admin);
        purrDeposit.updateStatusWithDrawAndDeposit(false);

        bytes4 selector = bytes4(keccak256("CanNotWithDraw()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.alice);
        purrDeposit.withDrawUser(20);
    }

    function test_WithDrawUser_ShouldRevert_WhenInvalidAmount() public {
        bytes4 selector = bytes4(keccak256("InvalidAmount(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 0));

        vm.prank(users.alice);
        purrDeposit.withDrawUser(0);
    }

    function test_WithDrawUser_ShouldRevert_WhenInsufficientTotalSupply() public {
        uint256 amountAddFund = 100e18;
        uint256 amountDeposit = 100e18;
        uint256 amountWithDraw = 220e18;

        vm.startPrank(users.admin);
        usd.approve(address(purrDeposit), amountAddFund);
        purrDeposit.addFund(amountAddFund);
        vm.stopPrank();

        vm.startPrank(users.alice);
        usd.approve(address(purrDeposit), amountDeposit);
        purrDeposit.addFund(amountDeposit);
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("InsufficientTotalSupply(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, amountWithDraw));

        vm.prank(users.alice);
        purrDeposit.withDrawUser(amountWithDraw);
    }

    function test_WithDrawUser_ShouldRevert_WhenInsufficientBalance() public {
        uint256 amountAddFund = 300e18;
        uint256 amountDeposit = 100e18;
        uint256 amountWithDraw = 200e18;

        vm.startPrank(users.admin);
        usd.approve(address(purrDeposit), amountAddFund);
        purrDeposit.addFund(amountAddFund);
        vm.stopPrank();

        vm.startPrank(users.alice);
        usd.approve(address(purrDeposit), amountDeposit);
        purrDeposit.deposit(amountDeposit);
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("InsufficientBalance(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, amountWithDraw));

        vm.prank(users.alice);
        purrDeposit.withDrawUser(amountWithDraw);
    }

    function test_WithDrawUser_ShouldWithDrawUsered() public {
        uint256 amountAddFund = 300e18;
        uint256 amountDeposit = 100e18;
        uint256 amountWithDraw = 50e18;

        vm.startPrank(users.admin);
        usd.approve(address(purrDeposit), amountAddFund);
        purrDeposit.addFund(amountAddFund);
        vm.stopPrank();

        vm.startPrank(users.alice);
        usd.approve(address(purrDeposit), amountDeposit);
        purrDeposit.deposit(amountDeposit);
        vm.stopPrank();

        uint256 preBalanceAlice = usd.balanceOf(users.alice);

        vm.prank(users.alice);
        purrDeposit.withDrawUser(amountWithDraw);

        uint256 posBalanceAlice = usd.balanceOf(users.alice);
        uint256 posBalancePurrDeposit = usd.balanceOf(address(purrDeposit));

        assertEq(purrDeposit.depositorInfo(users.alice), amountDeposit - amountWithDraw);
        assertEq(posBalanceAlice - preBalanceAlice, amountDeposit - amountWithDraw);
        assertEq(posBalancePurrDeposit, amountAddFund + amountDeposit - amountWithDraw);
        assertEq(purrDeposit.totalDeposit(), amountDeposit - amountWithDraw);
    }

    function test_WithDrawUser_ShouldEmit_EventWithDrawUser() public {
        uint256 amountAddFund = 300e18;
        uint256 amountDeposit = 100e18;
        uint256 amountWithDraw = 50e18;

        vm.startPrank(users.admin);
        usd.approve(address(purrDeposit), amountAddFund);
        purrDeposit.addFund(amountAddFund);
        vm.stopPrank();

        vm.startPrank(users.alice);
        usd.approve(address(purrDeposit), amountDeposit);
        purrDeposit.deposit(amountDeposit);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit WithDrawUser(users.alice, amountWithDraw, block.timestamp);

        vm.prank(users.alice);
        purrDeposit.withDrawUser(amountWithDraw);
    }

    function test_UpdateBalanceDepositor_ShouldRevert_WhenInvalidActiveStatus() public {
        uint256 length = 20;

        for (uint256 i; i < length;) {
            address iAddress = vm.addr(i + 1);
            _deal(iAddress, i + 1);
            depositorAddresses.push(address(iAddress));
            amounts.push(i);
            vm.startPrank(iAddress);
            usd.approve(address(purrDeposit), i + 1);
            purrDeposit.deposit(i + 1);
            vm.stopPrank();
            unchecked {
                ++i;
            }
        }
        bytes4 selector = bytes4(keccak256("InvalidActiveStatus()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrDeposit.updateBalanceDepositor(depositorAddresses, amounts);
    }

    function test_UpdateBalanceDepositor_ShouldRevert_WhenNotOwner() public {
        depositorAddresses.push(address(1));
        amounts.push(10);

        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrDeposit.updateBalanceDepositor(depositorAddresses, amounts);
    }

    function test_UpdateBalanceDepositor_ShouldRevert_InvalidArgument() public {
        depositorAddresses.push(address(1));
        amounts.push(10);
        amounts.push(20);
        vm.prank(users.subAdmin);
        purrDeposit.turnOffWithDrawAndDeposit();

        bytes4 selector = bytes4(keccak256("InvalidArgument()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrDeposit.updateBalanceDepositor(depositorAddresses, amounts);
    }

    function test_UpdateBalanceDepositor_ShouldUpdateBalanceDepositored() public {
        uint256 length = 20;
        uint256 totalVestedAmount;

        for (uint256 i; i < length;) {
            address iAddress = vm.addr(i + 1);
            _deal(iAddress, i + 1);
            depositorAddresses.push(address(iAddress));
            amounts.push(i);
            totalVestedAmount += i;
            vm.startPrank(iAddress);
            usd.approve(address(purrDeposit), i + 1);
            purrDeposit.deposit(i + 1);
            vm.stopPrank();
            unchecked {
                ++i;
            }
        }

        uint256 preTotalDeposit = purrDeposit.totalDeposit();

        vm.prank(users.subAdmin);
        purrDeposit.turnOffWithDrawAndDeposit();

        vm.prank(users.admin);
        purrDeposit.updateBalanceDepositor(depositorAddresses, amounts);

        uint256 depositLength = depositorAddresses.length;
        for (uint256 i; i < depositLength; ++i) {
            assertEq(purrDeposit.depositorInfo(depositorAddresses[i]), 1);
        }

        uint256 posTotalDeposit = purrDeposit.totalDeposit();

        assertEq(preTotalDeposit - totalVestedAmount, posTotalDeposit);
    }

    function test_TurnOffWithDraw_ShouldRevert_NotSubAdmin() public {
        bytes4 selector = bytes4(keccak256("InvalidSubAdmin(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrDeposit.turnOffWithDrawAndDeposit();
    }

    function test_TurnOffWithDraw_ShouldTurnOffWithDrawed() public {
        vm.prank(users.subAdmin);
        purrDeposit.turnOffWithDrawAndDeposit();

        assertEq(purrDeposit.canWithDrawAndDeposit(), false);
    }

    function test_UpdateStatusWithDraw_ShouldRevert_WhenNotOwner() public {
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrDeposit.updateStatusWithDrawAndDeposit(false);
    }

    function test_UpdateStatusWithDraw_ShouldUpdateStatusWithDrawed() public {
        vm.prank(users.admin);
        purrDeposit.updateStatusWithDrawAndDeposit(false);

        assertEq(purrDeposit.canWithDrawAndDeposit(), false);
    }

    function test_SetUsd_ShouldRevert_NotOwner() public {
        vm.prank(users.admin);
        MockUSD _usd = new MockUSD(users.admin);

        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrDeposit.setUsd(address(_usd));
    }

    function test_SetUsd_ShouldSetUsd() public {
        vm.startPrank(users.admin);
        MockUSD _usd = new MockUSD(users.admin);
        purrDeposit.setUsd(address(_usd));
        vm.stopPrank();

        assertEq(address(purrDeposit.usd()), address(_usd));
    }

    function test_SetRootAdmin_ShouldRevert_WhenNotRootAdmin() public {
        bytes4 selector = bytes4(keccak256("InvalidRootAdmin(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrDeposit.setRootAdmin(users.alice);
    }

    function test_SetRootAdmin_ShouldSetRootAdmined() public {
        vm.prank(users.rootAdmin);
        purrDeposit.setRootAdmin(users.rootAdmin);

        assertEq(users.rootAdmin, purrDeposit.rootAdmin());
    }

    function test_TransferOwnership_ShouldRevert_WhenNotRootAdminAndOwner() public {
        bytes4 selector1 = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector1, users.alice));

        vm.prank(users.alice);
        purrDeposit.transferOwnership(users.alice);

        bytes4 selector2 = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector2, users.subAdmin));

        vm.prank(users.subAdmin);
        purrDeposit.transferOwnership(users.subAdmin);
    }

    function test_TransferOwnership_ShouldTransferOwnershiped() public {
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

    function _deal(address _reciever, uint256 _amount) internal {
        vm.prank(users.admin);
        usd.mint(_reciever, _amount);
    }
}
