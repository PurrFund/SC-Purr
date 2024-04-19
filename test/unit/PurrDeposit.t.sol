// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseTest } from "../Base.t.sol";
import { MockUSD } from "../../test/mocks/MockUSD.sol";
import { PurrDeposit } from "../../src/PurrDeposit.sol";

contract PurrDepositTest is BaseTest {
    PurrDeposit public purrDeposit;

    event Deposit(address indexed depositor, address indexed receiver, uint256 amount, uint256 timeDeposit);
    event WithDrawRootAdmin(address indexed sender, address indexed receiver, uint256 amount);
    event UpdatePoolDeposit(bool canWithDraw);
    event WithDrawUser(address indexed sender, address indexed receiver, uint256 amount);
    event UpdateBalanceDepositor();
    event SetUsd(address usd);

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

    function test_UpdateStatusWithDraw_ShouldRevert_WhenNotOwner() public {
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrDeposit.updateStatusWithDraw(false);
    }

    function test_UpdateStatusWithDraw_ShouldUpdateStatusWithDraw() public {
        vm.prank(users.admin);
        purrDeposit.updateStatusWithDraw(false);

        assertEq(purrDeposit.canWithDraw(), false);
    }

    function test_UpdateStatusWithDraw_ShouldEmit_EventUpdatePoolDeposit() public {
        vm.expectEmit(true, false, false, true);
        emit UpdatePoolDeposit(false);

        vm.prank(users.admin);
        purrDeposit.updateStatusWithDraw(false);
    }

    function test_WithDrawUser_ShouldReVert_WhenCanNotWithDraw() public { 
        vm.prank(users.admin);
        purrDeposit.updateStatusWithDraw(false);

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
        bytes4 selector = bytes4(keccak256("InsufficientTotalSupply(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 20));

        vm.prank(users.alice);
        purrDeposit.withDrawUser(20);
    }

    function test_WithDrawUser_ShouldRevert_WhenInsufficientBalance() public { 
        vm.startPrank(users.admin);
        usd.approve(address(purrDeposit), 100);
        purrDeposit.addFund(100);
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("InsufficientBalance(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 20));

        vm.prank(users.alice);
        purrDeposit.withDrawUser(20);
    }

    function test_WithDrawUser_ShouldWithDrawUsered() public { 
        vm.startPrank(users.admin);
        usd.approve(address(purrDeposit), 100);
        purrDeposit.addFund(100);
        vm.stopPrank();

        vm.startPrank(users.alice);
        usd.approve(address(purrDeposit), 30);
        purrDeposit.deposit(30);
        vm.stopPrank();

        uint256 preBalanceUser = usd.balanceOf(users.alice);
        uint256 preBalancePurrDeposit = usd.balanceOf(address(purrDeposit));

        vm.prank(address(purrDeposit));
        usd.approve(address(purrDeposit), 20);

        vm.prank(users.alice);
        purrDeposit.withDrawUser(20);
        
        uint256 posBalanceUser = usd.balanceOf(users.alice);
        uint256 posBalancePurrDeposit = usd.balanceOf(address(purrDeposit)); 

        assertEq(purrDeposit.depositorInfo(users.alice), 10);
        assertEq(posBalanceUser - preBalanceUser, 20);
        assertEq(preBalancePurrDeposit - posBalancePurrDeposit, 20);
    }

    function test_WithDrawUser_ShouldEmit_EventWithDrawUser() public { 
        vm.startPrank(users.admin);
        usd.approve(address(purrDeposit), 100);
        purrDeposit.addFund(100);
        vm.stopPrank();

        vm.startPrank(users.alice);
        usd.approve(address(purrDeposit), 30);
        purrDeposit.deposit(30);
        vm.stopPrank();

        vm.prank(address(purrDeposit));
        usd.approve(address(purrDeposit), 20);

        vm.expectEmit(true, true, true, true);
        emit WithDrawUser(address(purrDeposit), users.alice, 20);

        vm.prank(users.alice);
        purrDeposit.withDrawUser(20);
    }

    // test updateBalanceDepositor
    address[] depositorAddresses = [address(1), address(2), address(3)];
    uint256[] amounts = [30, 60, 90];
    uint256[] _amounts = [30, 60];

    function test_UpdateBalanceDepositor_ShouldRevert_InvalidArgument() public {
        bytes4 selector = bytes4(keccak256("InvalidArgument()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrDeposit.updateBalanceDepositor(depositorAddresses, _amounts);
    }

    function test_UpdateBalanceDepositor_ShouldUpdateBalanceDepositor() public {
        vm.prank(users.admin);
        purrDeposit.updateBalanceDepositor(depositorAddresses, amounts);    

        uint256 depositLength = depositorAddresses.length;
        for(uint256 i; i < depositLength; ++i){
            assertEq(purrDeposit.depositorInfo(depositorAddresses[i]), amounts[i]);
        }
    }

    // function test_UpdateBalanceDepositor_ShouldEmit_EventUpdateBalanceDepositor() public {
    //     vm.expectEmit(true, true, true, true);
    //     emit UpdateBalanceDepositor();

    //     vm.prank(users.admin);
    //     purrDeposit.updateBalanceDepositor(depositorAddresses, amounts);    
    // }

    function test_TurnOffWithDraw_ShouldRevert_NotSubAdmin() public {
        bytes4 selector = bytes4(keccak256("InvalidSubAdmin(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrDeposit.turnOffWihDraw();
    }

    function test_TurnOffWithDraw_ShouldTurnOffWithDraw() public {
        vm.prank(users.subAdmin);
        purrDeposit.turnOffWihDraw();

        assertEq(purrDeposit.canWithDraw(), false);
    }

    function test_TurnOffWithDraw_ShouldEmit_EventUpdatePoolDeposit() public {
        vm.expectEmit(true, false, false, true);
        emit UpdatePoolDeposit(false);

        vm.prank(users.subAdmin);
        purrDeposit.turnOffWihDraw();
    }
    
    function test_SetUsd_ShouldRevert_NotOwner() public {
        vm.prank(users.admin);
        MockUSD _usd = new MockUSD(users.admin);

        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrDeposit.setUsdc(address(_usd));
    }

    function test_SetUsdc_ShouldSetUsd() public {
        vm.startPrank(users.admin);
        MockUSD _usd = new MockUSD(users.admin);
        purrDeposit.setUsdc(address(_usd));
        vm.stopPrank();

        assertEq(address(purrDeposit.usd()), address(_usd));
    }

    function test_SetUsdc_ShouldEmit_EventSetUsd() public{
        vm.prank(users.admin);
        MockUSD _usd = new MockUSD(users.admin);

        vm.expectEmit(true, false, false, true);
        emit SetUsd(address(_usd));

        vm.prank(users.admin);
        purrDeposit.setUsdc(address(_usd));
    }

    function _deal(address _reciever, uint256 _amount) internal {
        vm.prank(users.admin);
        usd.mint(_reciever, _amount);
    }
}
