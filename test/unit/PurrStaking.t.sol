// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { BaseTest } from "../Base.t.sol";

import { UserPoolInfo, PoolInfo, PoolType, TierType, TierInfo } from "../../src/types/PurrStaingType.sol";
import { PurrToken } from "../../src/token/PurrToken.sol";
import { PurrStaking } from "../../src/PurrStaking.sol";

contract PurrStakingTest is BaseTest {
    using Math for uint256;

    // need test for multiple stake and unstake action
    PurrStaking purrStaking;
    PurrToken launchPadToken;
    uint256 initBalance;
    PoolInfo[] poolInfos;
    TierInfo[] tierInfos;
    uint256[] itemIds;

    event Stake(
        address indexed staker,
        uint256 indexed itemId,
        uint256 amount,
        uint256 pPoint,
        uint64 updateAt,
        uint64 end,
        PoolType poolType
    );
    event UnStake(address indexed staker, uint256 itemId, uint256 unStakeAmount, uint256 lossPoint, uint64 time, PoolType pool);
    event ClaimReward(address indexed claimer, uint256 itemId, uint256 amount, uint64 claimAt);
    event UpdatePool(PoolInfo pool);
    event UpdateTier(TierInfo tier);
    event ClaimUnstakePoolOne(address staker, uint256 itemId, uint256 amount, uint64 claimTime);
    event ClaimPendingReward(address staker, uint256 itemId, uint256 amount, uint64 claimTime);

    function setUp() public {
        _initPools();
        _initTiers();
        launchPadToken = new PurrToken(users.admin, "LaunchPad", "LP");
        purrStaking = new PurrStaking(address(launchPadToken), users.admin, poolInfos, tierInfos);
        initBalance = 10_000e18;
        _deal(users.alice, initBalance);
        _deal(users.admin, initBalance);
        _deal(users.bob, initBalance);
        _deal(address(purrStaking), initBalance);

        vm.startPrank(users.admin);
        purrStaking.pause();
        purrStaking.unpause();
        vm.stopPrank();
    }

    function test_Stake_ShouldRevert_WhenInvalidAmount() public {
        uint256 amount = 0;
        bytes4 selector = bytes4(keccak256("InvalidAmount(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, amount));

        vm.prank(users.alice);
        purrStaking.stake(amount, PoolType.THREE);
    }

    function test_Stake_ShouldStaked() public {
        uint256 amount = 100e18;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.THREE);
        vm.stopPrank();
        (,, uint16 multiplier, uint32 lockDay,, uint256 totalStaked, uint256 numberStaker,) = purrStaking.poolInfo(PoolType.THREE);
        (   
            uint64 startAt,
            uint64 updateAt,
            uint64 end,
            uint64 timeUnstaked,
            uint256 amountAvailable,
            address staker,
            uint256 pPoint,
            uint256 stakedAmount,
            PoolType poolType
        ) = purrStaking.userPoolInfo(purrStaking.itemId());

        // assert poolInfo
        assertEq(totalStaked, amount);
        assertEq(numberStaker, 1);

        // assert item Id
        assertEq(purrStaking.itemId(), 1);

        // assert userPoolInfo
        uint256 pointExpect = (amount * multiplier) / 10;

        assertEq(startAt, block.timestamp);
        assertEq(updateAt, block.timestamp);
        assertEq(end, block.timestamp + lockDay);
        assertEq(timeUnstaked, 0);
        assertEq(amountAvailable, 0);
        assertEq(staker, users.alice);
        assertEq(pPoint, pointExpect);
        assertEq(stakedAmount, amount);
        assertEq(uint8(poolType), uint8(PoolType.THREE));
        vm.prank(users.alice);
        assertEq(purrStaking.getUserItemId(users.alice)[0], 1);
        assertEq(launchPadToken.balanceOf(users.alice), initBalance - amount);
        uint256 posPurrBL = amount + initBalance;
        assertEq(launchPadToken.balanceOf(address(purrStaking)), posPurrBL);
    }

    function test_Stake_ShouleEmit_EventStake() public {
        uint256 amount = 100e18;
        (,, uint16 multiplier, uint32 lockDay,,,,) = purrStaking.poolInfo(PoolType.FOUR);
        uint256 pointExpect = (amount * multiplier) / 10;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);

        vm.expectEmit(true, true, true, true);
        emit Stake(
            users.alice,
            purrStaking.itemId() + 1,
            amount,
            pointExpect,
            uint64(block.timestamp),
            uint64(block.timestamp + lockDay),
            PoolType.FOUR
        );

        purrStaking.stake(amount, PoolType.FOUR);
        vm.stopPrank();
    }

    function test_Unstake_ShouldRevert_WhenInvalidAmount() public {
        uint256 amount = 10e18;
        uint256 itemId = 1;
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.THREE);
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("InvalidAmount(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 0));

        vm.prank(users.alice);
        purrStaking.unstake(0, itemId);

        uint256 exceedAmount = 11e18;
        vm.startPrank(users.alice);

        bytes4 selector2 = bytes4(keccak256("InvalidAmount(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector2, exceedAmount));
        purrStaking.unstake(exceedAmount, itemId);

        vm.stopPrank();
    }

    function test_Unstake_ShouldRevert_WhenInvalidStaker() public {
        uint256 amount = 10e18;
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.THREE);
        vm.stopPrank();

        purrStaking.userPoolInfo(1);

        bytes4 selector = bytes4(keccak256("InvalidStaker(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.bob));
        vm.prank(users.bob);
        purrStaking.unstake(amount, 1);
    }

    function test_Unstake_ShouldUnstaked_Amount_WhenExpire_PoolTwo() public {
        uint256 amountStake = initBalance;
        uint256 amountUnstake = 10e18;
        uint256 itemId = 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amountStake);
        purrStaking.stake(amountStake, PoolType.TWO);
        vm.stopPrank();

        uint256 preAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 prePurrBL = launchPadToken.balanceOf(address(purrStaking));
        (   
            uint64 preStartAt,
            ,
            uint64 preEnd,
            uint64 preTimeUnstaked,
            uint256 preAmountAvailable,
            address preStaker,
            uint256 prePPoint,
            uint256 preStakedAmount,
        ) = purrStaking.userPoolInfo(itemId);

        (
            uint16 preUnstakeFee,
            uint16 preApy,
            uint16 multiplier,
            uint32 preLockDay,
            uint32 preUnstakeTime,
            uint256 preTotalStaked,
            uint256 preNumberStaker,
        ) = purrStaking.poolInfo(PoolType.TWO);

        uint64 nextTimeStamp = uint64(block.timestamp + preLockDay + 1 seconds);
        vm.warp(nextTimeStamp);

        uint256 pendingReward = purrStaking.getPendingReward(itemId);
        vm.prank(users.alice);
        purrStaking.unstake(amountUnstake, itemId);

        uint256 posAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 posPurrBL = launchPadToken.balanceOf(address(purrStaking));
        (
            uint64 posStartAt,
            uint64 posUpdateAt,
            uint64 posEnd,
            uint64 posTimeUnstaked,
            uint256 posAmountAvailable,
            address posStaker,
            uint256 posPPoint,
            uint256 posStakedAmount,
        ) = purrStaking.userPoolInfo(itemId);

        (
            uint16 posUnstakeFee,
            uint16 posApy,
            ,
            uint32 posLockDay,
            uint32 posUnstakeTime,
            uint256 posTotalStaked,
            uint256 posNumberStaker,
        ) = purrStaking.poolInfo(PoolType.TWO);

        UserPoolInfo memory expectUserPool = UserPoolInfo({
            startAt: preStartAt,
            updateAt: nextTimeStamp,
            end: preEnd,
            timeUnstaked: preTimeUnstaked,
            amountAvailable: preAmountAvailable,
            staker: preStaker,
            pPoint: prePPoint - (amountUnstake * multiplier) / 10,
            stakedAmount: preStakedAmount - amountUnstake,
            poolType: PoolType.TWO
        });

        PoolInfo memory expectPoolInfo = PoolInfo({
            unstakeFee: preUnstakeFee,
            apy: preApy,
            multiplier: multiplier,
            lockDay: preLockDay,
            unstakeTime: preUnstakeTime,
            totalStaked: preTotalStaked - amountUnstake,
            numberStaker: preNumberStaker,
            poolType: PoolType.TWO
        });

        UserPoolInfo memory actualUserPool = UserPoolInfo(
            posStartAt, posUpdateAt, posEnd, posTimeUnstaked, posAmountAvailable, posStaker, posPPoint, posStakedAmount, PoolType.TWO
        );
        PoolInfo memory actualPoolInfo =
            PoolInfo(posUnstakeFee, posApy, multiplier, posLockDay, posUnstakeTime, posTotalStaked, posNumberStaker, PoolType.TWO);

        assertEq(abi.encode(expectUserPool), abi.encode(actualUserPool));
        assertEq(abi.encode(expectPoolInfo), abi.encode(actualPoolInfo));
        assertEq(preAliceBL + amountUnstake + pendingReward, posAliceBL);
        assertEq(prePurrBL - amountUnstake - pendingReward, posPurrBL);
    }

    function test_Unstake_ShouldUnstaked_All_WhenExpire_PoolTwo() public {
        uint256 amountStake = initBalance;
        uint256 amountUnstake = initBalance;
        uint256 itemId = 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amountStake);
        purrStaking.stake(amountStake, PoolType.TWO);
        vm.stopPrank();

        uint256 preAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 prePurrBL = launchPadToken.balanceOf(address(purrStaking));

        (
            uint16 preUnstakeFee,
            uint16 preApy,
            uint16 multiplier,
            uint32 preLockDay,
            uint32 preUnstakeTime,
            uint256 preTotalStaked,
            uint256 preNumberStaker,
        ) = purrStaking.poolInfo(PoolType.TWO);

        uint64 nextTimeStamp = uint64(block.timestamp + preLockDay + 1 seconds);
        vm.warp(nextTimeStamp);

        uint256 pendingReward = purrStaking.getPendingReward(itemId);
        vm.prank(users.alice);
        purrStaking.unstake(amountUnstake, itemId);

        uint256 posAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 posPurrBL = launchPadToken.balanceOf(address(purrStaking));
        (,,,,, address posStaker,,,) = purrStaking.userPoolInfo(itemId);

        assertEq(posStaker, address(0));
        assertEq(purrStaking.itemIdIndexInfo(itemId), 0);
        // assert Eq delete itemId
        // assertEq(purrStaking.userItemInfo())

        (
            uint16 posUnstakeFee,
            uint16 posApy,
            ,
            uint32 posLockDay,
            uint32 posUnstakeTime,
            uint256 posTotalStaked,
            uint256 posNumberStaker,
        ) = purrStaking.poolInfo(PoolType.TWO);

        PoolInfo memory expectPoolInfo = PoolInfo({
            unstakeFee: preUnstakeFee,
            apy: preApy,
            multiplier: multiplier,
            lockDay: preLockDay,
            unstakeTime: preUnstakeTime,
            totalStaked: preTotalStaked - amountUnstake,
            numberStaker: preNumberStaker - 1,
            poolType: PoolType.TWO
        });

        PoolInfo memory actualPoolInfo =
            PoolInfo(posUnstakeFee, posApy, multiplier, posLockDay, posUnstakeTime, posTotalStaked, posNumberStaker, PoolType.TWO);

        assertEq(abi.encode(expectPoolInfo), abi.encode(actualPoolInfo));
        assertEq(preAliceBL + amountUnstake + pendingReward, posAliceBL);
        assertEq(prePurrBL - amountUnstake - pendingReward, posPurrBL);
    }

    function test_Unstake_ShouldUnstaked_Amount_WhenNotExpire_PoolTwo() public {
        uint256 amountStake = initBalance;
        uint256 amountUnstake = 10e18;
        uint256 itemId = 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amountStake);
        purrStaking.stake(amountStake, PoolType.TWO);
        vm.stopPrank();

        uint256 preAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 prePurrBL = launchPadToken.balanceOf(address(purrStaking));
        (   
            uint64 preStartAt,
            ,
            uint64 preEnd,
            uint64 preTimeUnstaked,
            uint256 preAmountAvailable,
            address preStaker,
            uint256 prePPoint,
            uint256 preStakedAmount,
        ) = purrStaking.userPoolInfo(itemId);

        (
            uint16 preUnstakeFee,
            uint16 preApy,
            uint16 multiplier,
            uint32 preLockDay,
            uint32 preUnstakeTime,
            uint256 preTotalStaked,
            uint256 preNumberStaker,
        ) = purrStaking.poolInfo(PoolType.TWO);

        uint64 nextTimeStamp = uint64(block.timestamp + preLockDay - 1 seconds);
        vm.warp(nextTimeStamp);

        uint256 pendingReward = purrStaking.getPendingReward(itemId);
        vm.prank(users.alice);
        purrStaking.unstake(amountUnstake, itemId);

        uint256 posAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 posPurrBL = launchPadToken.balanceOf(address(purrStaking));
        (
            uint64 posStartAt,
            uint64 posUpdateAt,
            uint64 posEnd,
            uint64 posTimeUnstaked,
            uint256 posAmountAvailable,
            address posStaker,
            uint256 posPPoint,
            uint256 posStakedAmount,
        ) = purrStaking.userPoolInfo(itemId);

        (
            uint16 posUnstakeFee,
            uint16 posApy,
            ,
            uint32 posLockDay,
            uint32 posUnstakeTime,
            uint256 posTotalStaked,
            uint256 posNumberStaker,
        ) = purrStaking.poolInfo(PoolType.TWO);

        uint256 realAmountUnstake =
            amountUnstake - amountUnstake.mulDiv(posUnstakeFee, 10_000, Math.Rounding.Floor) + pendingReward;

        UserPoolInfo memory expectUserPool = UserPoolInfo({
            startAt: preStartAt,
            updateAt: nextTimeStamp,
            end: preEnd,
            timeUnstaked: preTimeUnstaked,
            amountAvailable: preAmountAvailable,
            staker: preStaker,
            pPoint: prePPoint - (amountUnstake * multiplier) / 10,
            stakedAmount: preStakedAmount - amountUnstake,
            poolType: PoolType.TWO
        });

        PoolInfo memory expectPoolInfo = PoolInfo({
            unstakeFee: preUnstakeFee,
            apy: preApy,
            multiplier: multiplier,
            lockDay: preLockDay,
            unstakeTime: preUnstakeTime,
            totalStaked: preTotalStaked - amountUnstake,
            numberStaker: preNumberStaker,
            poolType: PoolType.TWO
        });

        UserPoolInfo memory actualUserPool = UserPoolInfo(
            posStartAt, posUpdateAt, posEnd, posTimeUnstaked, posAmountAvailable, posStaker, posPPoint, posStakedAmount, PoolType.TWO
        );
        PoolInfo memory actualPoolInfo =
            PoolInfo(posUnstakeFee, posApy, multiplier, posLockDay, posUnstakeTime, posTotalStaked, posNumberStaker, PoolType.TWO);

        assertEq(abi.encode(expectUserPool), abi.encode(actualUserPool));
        assertEq(abi.encode(expectPoolInfo), abi.encode(actualPoolInfo));
        assertEq(preAliceBL + realAmountUnstake, posAliceBL);
        assertEq(prePurrBL - amountUnstake - pendingReward, posPurrBL);
    }

    function test_Unstake_ShouldUnstaked_All_WhenNotExpire_PoolTwo() public {
        uint256 amountStake = initBalance;
        uint256 amountUnstake = initBalance;
        uint256 itemId = 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amountStake);
        purrStaking.stake(amountStake, PoolType.TWO);
        vm.stopPrank();

        uint256 preAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 prePurrBL = launchPadToken.balanceOf(address(purrStaking));

        (
            uint16 preUnstakeFee,
            uint16 preApy,
            uint16 multiplier,
            uint32 preLockDay,
            uint32 preUnstakeTime,
            uint256 preTotalStaked,
            uint256 preNumberStaker,
        ) = purrStaking.poolInfo(PoolType.TWO);

        uint64 nextTimeStamp = uint64(block.timestamp + preLockDay - 1 seconds);
        vm.warp(nextTimeStamp);

        uint256 pendingReward = purrStaking.getPendingReward(itemId);
        vm.prank(users.alice);
        purrStaking.unstake(amountUnstake, itemId);

        uint256 posAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 posPurrBL = launchPadToken.balanceOf(address(purrStaking));
        (,,,,, address posStaker,,,) = purrStaking.userPoolInfo(itemId);

        assertEq(posStaker, address(0));
        assertEq(purrStaking.itemIdIndexInfo(itemId), 0);
        // assert Eq delete itemId
        // assertEq(purrStaking.userItemInfo())

        (
            uint16 posUnstakeFee,
            uint16 posApy,
            ,
            uint32 posLockDay,
            uint32 posUnstakeTime,
            uint256 posTotalStaked,
            uint256 posNumberStaker,
        ) = purrStaking.poolInfo(PoolType.TWO);

        uint256 realAmountUnstake =
            amountUnstake - amountUnstake.mulDiv(posUnstakeFee, 10_000, Math.Rounding.Floor) + pendingReward;

        PoolInfo memory expectPoolInfo = PoolInfo({
            unstakeFee: preUnstakeFee,
            apy: preApy,
            multiplier: multiplier,
            lockDay: preLockDay,
            unstakeTime: preUnstakeTime,
            totalStaked: preTotalStaked - amountUnstake,
            numberStaker: preNumberStaker - 1,
            poolType: PoolType.TWO
        });

        PoolInfo memory actualPoolInfo =
            PoolInfo(posUnstakeFee, posApy, multiplier, posLockDay, posUnstakeTime, posTotalStaked, posNumberStaker, PoolType.TWO);

        assertEq(abi.encode(expectPoolInfo), abi.encode(actualPoolInfo));
        assertEq(preAliceBL + realAmountUnstake, posAliceBL);
        assertEq(prePurrBL - amountUnstake - pendingReward, posPurrBL);
    }

    function test_Unstake_ShouldEmit_EventUnStake_All_PoolTwo() public {
        uint256 amountStake = initBalance;
        uint256 amountUnstake = initBalance;
        uint256 itemId = 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amountStake);
        purrStaking.stake(amountStake, PoolType.TWO);
        vm.stopPrank();

        (,, uint16 multiplier, uint32 preLockDay,,,,) = purrStaking.poolInfo(PoolType.TWO);

        uint64 nextTimeStamp = uint64(block.timestamp + preLockDay - 1 seconds);
        vm.warp(nextTimeStamp);

        vm.expectEmit(true, true, true, true);
        emit UnStake(users.alice, 1, amountUnstake, (amountUnstake * multiplier) / 10, uint64(block.timestamp), PoolType.TWO);

        vm.prank(users.alice);
        purrStaking.unstake(amountUnstake, itemId);
    }

    function test_Unstake_ShouldUnstaked_Amount_WhenExpire_PoolOne() public {
        uint256 amountStake = initBalance;
        uint256 amountUnstake = 10e18;
        uint256 itemId = 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amountStake);
        purrStaking.stake(amountStake, PoolType.ONE);
        vm.stopPrank();

        uint256 preAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 prePurrBL = launchPadToken.balanceOf(address(purrStaking));
        (
            uint64 preStartAt,
            ,
            uint64 preEnd,
            uint64 preTimeUnstaked,
            uint256 preAmountAvailable,
            address preStaker,
            uint256 prePPoint,
            uint256 preStakedAmount,
        ) = purrStaking.userPoolInfo(itemId);

        (
            uint16 preUnstakeFee,
            uint16 preApy,
            uint16 multiplier,
            uint32 preLockDay,
            uint32 preUnstakeTime,
            uint256 preTotalStaked,
            uint256 preNumberStaker,
        ) = purrStaking.poolInfo(PoolType.ONE);

        uint64 nextTimeStamp = uint64(block.timestamp + preLockDay + 1 seconds);
        vm.warp(nextTimeStamp);

        uint256 pendingReward = purrStaking.getPendingReward(itemId);
        vm.prank(users.alice);
        purrStaking.unstake(amountUnstake, itemId);

        uint256 posAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 posPurrBL = launchPadToken.balanceOf(address(purrStaking));
        (
            uint64 posStartAt,
            uint64 posUpdateAt,
            uint64 posEnd,
            uint64 posTimeUnstaked,
            uint256 posAmountAvailable,
            address posStaker,
            uint256 posPPoint,
            uint256 posStakedAmount,
        ) = purrStaking.userPoolInfo(itemId);

        (
            uint16 posUnstakeFee,
            uint16 posApy,
            ,
            uint32 posLockDay,
            uint32 posUnstakeTime,
            uint256 posTotalStaked,
            uint256 posNumberStaker,
        ) = purrStaking.poolInfo(PoolType.ONE);

        UserPoolInfo memory expectUserPool = UserPoolInfo({
            startAt: preStartAt,
            updateAt: nextTimeStamp,
            end: preEnd,
            timeUnstaked: preTimeUnstaked,
            amountAvailable: preAmountAvailable,
            staker: preStaker,
            pPoint: prePPoint - (amountUnstake * multiplier) / 10,
            stakedAmount: preStakedAmount - amountUnstake,
            poolType: PoolType.ONE
        });

        PoolInfo memory expectPoolInfo = PoolInfo({
            unstakeFee: preUnstakeFee,
            apy: preApy,
            multiplier: multiplier,
            lockDay: preLockDay,
            unstakeTime: preUnstakeTime,
            totalStaked: preTotalStaked - amountUnstake,
            numberStaker: preNumberStaker,
            poolType: PoolType.ONE
        });

        UserPoolInfo memory actualUserPool = UserPoolInfo(
            posStartAt, posUpdateAt, posEnd, posTimeUnstaked, posAmountAvailable, posStaker, posPPoint, posStakedAmount, PoolType.ONE
        );
        PoolInfo memory actualPoolInfo =
            PoolInfo(posUnstakeFee, posApy, multiplier, posLockDay, posUnstakeTime, posTotalStaked, posNumberStaker, PoolType.ONE);

        assertEq(abi.encode(expectUserPool), abi.encode(actualUserPool));
        assertEq(abi.encode(expectPoolInfo), abi.encode(actualPoolInfo));
        assertEq(preAliceBL + amountUnstake + pendingReward, posAliceBL);
        assertEq(prePurrBL - amountUnstake - pendingReward, posPurrBL);
    }

    function test_Unstake_ShouldUnstaked_All_WhenExpire_PoolTOne() public {
        uint256 amountStake = initBalance;
        uint256 amountUnstake = initBalance;
        uint256 itemId = 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amountStake);
        purrStaking.stake(amountStake, PoolType.TWO);
        vm.stopPrank();

        uint256 preAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 prePurrBL = launchPadToken.balanceOf(address(purrStaking));

        (
            uint16 preUnstakeFee,
            uint16 preApy,
            uint16 multiplier,
            uint32 preLockDay,
            uint32 preUnstakeTime,
            uint256 preTotalStaked,
            uint256 preNumberStaker,
        ) = purrStaking.poolInfo(PoolType.TWO);

        uint64 nextTimeStamp = uint64(block.timestamp + preLockDay + 1 seconds);
        vm.warp(nextTimeStamp);

        uint256 pendingReward = purrStaking.getPendingReward(itemId);
        vm.prank(users.alice);
        purrStaking.unstake(amountUnstake, itemId);

        uint256 posAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 posPurrBL = launchPadToken.balanceOf(address(purrStaking));
        (,,,,, address posStaker,,,) = purrStaking.userPoolInfo(itemId);

        assertEq(posStaker, address(0));
        assertEq(purrStaking.itemIdIndexInfo(itemId), 0);
        // assert Eq delete itemId
        // assertEq(purrStaking.userItemInfo())

        (
            uint16 posUnstakeFee,
            uint16 posApy,
            ,
            uint32 posLockDay,
            uint32 posUnstakeTime,
            uint256 posTotalStaked,
            uint256 posNumberStaker,
        ) = purrStaking.poolInfo(PoolType.TWO);

        PoolInfo memory expectPoolInfo = PoolInfo({
            unstakeFee: preUnstakeFee,
            apy: preApy,
            multiplier: multiplier,
            lockDay: preLockDay,
            unstakeTime: preUnstakeTime,
            totalStaked: preTotalStaked - amountUnstake,
            numberStaker: preNumberStaker - 1,
            poolType: PoolType.TWO
        });

        PoolInfo memory actualPoolInfo =
            PoolInfo(posUnstakeFee, posApy, multiplier, posLockDay, posUnstakeTime, posTotalStaked, posNumberStaker, PoolType.TWO);

        assertEq(abi.encode(expectPoolInfo), abi.encode(actualPoolInfo));
        assertEq(preAliceBL + amountUnstake + pendingReward, posAliceBL);
        assertEq(prePurrBL - amountUnstake - pendingReward, posPurrBL);
    }

    function test_Unstake_ShouldUnstaked_Amount_WhenNotExpire_PoolOne() public {
        uint256 amountStake = initBalance;
        uint256 amountUnstake = 10e18;
        uint256 itemId = 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amountStake);
        purrStaking.stake(amountStake, PoolType.ONE);
        vm.stopPrank();

        uint256 preAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 prePurrBL = launchPadToken.balanceOf(address(purrStaking));
        (uint64 preStartAt, , uint64 preEnd,, uint256 preAmountAvailable, address preStaker, uint256 prePPoint, uint256 preStakedAmount,) =
            purrStaking.userPoolInfo(itemId);

        (
            uint16 preUnstakeFee,
            uint16 preApy,
            uint16 multiplier,
            uint32 preLockDay,
            uint32 preUnstakeTime,
            uint256 preTotalStaked,
            uint256 preNumberStaker,
        ) = purrStaking.poolInfo(PoolType.ONE);

        uint64 nextTimeStamp = uint64(block.timestamp + preLockDay - 1 seconds);
        vm.warp(nextTimeStamp);

        uint256 pendingReward = purrStaking.getPendingReward(itemId);
        vm.prank(users.alice);
        purrStaking.unstake(amountUnstake, itemId);

        uint256 posAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 posPurrBL = launchPadToken.balanceOf(address(purrStaking));

        (
            uint64 posStartAt,
            uint64 posUpdateAt,
            uint64 posEnd,
            uint64 posTimeUnstaked,
            uint256 posAmountAvailable,
            address posStaker,
            uint256 posPPoint,
            uint256 posStakedAmount,
        ) = purrStaking.userPoolInfo(itemId);

        (
            uint16 posUnstakeFee,
            uint16 posApy,
            ,
            uint32 posLockDay,
            uint32 posUnstakeTime,
            uint256 posTotalStaked,
            uint256 posNumberStaker,
        ) = purrStaking.poolInfo(PoolType.ONE);

        UserPoolInfo memory expectUserPool = UserPoolInfo({
            startAt: preStartAt,
            updateAt: nextTimeStamp,
            end: preEnd,
            timeUnstaked: nextTimeStamp + preUnstakeTime,
            amountAvailable: preAmountAvailable + pendingReward + amountUnstake,
            staker: preStaker,
            pPoint: prePPoint - (amountUnstake * multiplier) / 10,
            stakedAmount: preStakedAmount - amountUnstake,
            poolType: PoolType.ONE
        });

        PoolInfo memory expectPoolInfo = PoolInfo({
            unstakeFee: preUnstakeFee,
            apy: preApy,
            multiplier: multiplier,
            lockDay: preLockDay,
            unstakeTime: preUnstakeTime,
            totalStaked: preTotalStaked - amountUnstake,
            numberStaker: preNumberStaker,
            poolType: PoolType.ONE
        });

        UserPoolInfo memory actualUserPool = UserPoolInfo(
            posStartAt, posUpdateAt, posEnd, posTimeUnstaked, posAmountAvailable, posStaker, posPPoint, posStakedAmount, PoolType.ONE
        );
        PoolInfo memory actualPoolInfo =
            PoolInfo(posUnstakeFee, posApy, multiplier, posLockDay, posUnstakeTime, posTotalStaked, posNumberStaker, PoolType.ONE);

        assertEq(abi.encode(expectUserPool), abi.encode(actualUserPool));
        assertEq(abi.encode(expectPoolInfo), abi.encode(actualPoolInfo));
        assertEq(preAliceBL, posAliceBL);
        assertEq(prePurrBL, posPurrBL);
    }

    function test_Unstake_ShouldUnstaked_All_WhenNotExpire_PoolOne() public {
        uint256 amountStake = initBalance;
        uint256 amountUnstake = initBalance;
        uint256 itemId = 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amountStake);
        purrStaking.stake(amountStake, PoolType.ONE);
        vm.stopPrank();

        uint256 preAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 prePurrBL = launchPadToken.balanceOf(address(purrStaking));

        (uint64 preStartAt, , uint64 preEnd,, uint256 preAmountAvailable, address preStaker, uint256 prePPoint, uint256 preStakedAmount,) =
            purrStaking.userPoolInfo(itemId);

        (
            uint16 preUnstakeFee,
            uint16 preApy,
            uint16 multiplier,
            uint32 preLockDay,
            uint32 preUnstakeTime,
            uint256 preTotalStaked,
            ,
        ) = purrStaking.poolInfo(PoolType.ONE);

        uint64 nextTimeStamp = uint64(block.timestamp + preLockDay - 1 seconds);
        vm.warp(nextTimeStamp);

        uint256 pendingReward = purrStaking.getPendingReward(itemId);
        vm.prank(users.alice);
        purrStaking.unstake(amountUnstake, itemId);

        uint256 posAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 posPurrBL = launchPadToken.balanceOf(address(purrStaking));
        (
            uint64 posStartAt,
            uint64 posUpdateAt,
            uint64 posEnd,
            uint64 posTimeUnstaked,
            uint256 posAmountAvailable,
            address posStaker,
            uint256 posPPoint,
            uint256 posStakedAmount,
        ) = purrStaking.userPoolInfo(itemId);

        // assert Eq delete itemId
        // assertEq(purrStaking.userItemInfo())

        (
            uint16 posUnstakeFee,
            uint16 posApy,
            ,
            uint32 posLockDay,
            uint32 posUnstakeTime,
            uint256 posTotalStaked,
            uint256 posNumberStaker,
        ) = purrStaking.poolInfo(PoolType.ONE);

        UserPoolInfo memory expectUserPool = UserPoolInfo({
            startAt: preStartAt,
            updateAt: nextTimeStamp,
            end: preEnd,
            timeUnstaked: nextTimeStamp + preUnstakeTime,
            amountAvailable: preAmountAvailable + pendingReward + amountUnstake,
            staker: preStaker,
            pPoint: prePPoint - (amountUnstake * multiplier) / 10,
            stakedAmount: preStakedAmount - amountUnstake,
            poolType: PoolType.ONE
        });

        PoolInfo memory expectPoolInfo = PoolInfo({
            unstakeFee: preUnstakeFee,
            apy: preApy,
            multiplier: multiplier,
            lockDay: preLockDay,
            unstakeTime: preUnstakeTime,
            totalStaked: preTotalStaked - amountUnstake,
            numberStaker: 0,
            poolType: PoolType.ONE
        });

        PoolInfo memory actualPoolInfo =
            PoolInfo(posUnstakeFee, posApy, multiplier, posLockDay, posUnstakeTime, posTotalStaked, posNumberStaker, PoolType.ONE);

        UserPoolInfo memory actualUserPool = UserPoolInfo(
            posStartAt, posUpdateAt, posEnd, posTimeUnstaked, posAmountAvailable, posStaker, posPPoint, posStakedAmount, PoolType.ONE
        );

        assertEq(abi.encode(expectPoolInfo), abi.encode(actualPoolInfo));
        assertEq(abi.encode(expectUserPool), abi.encode(actualUserPool));
        assertEq(preAliceBL, posAliceBL);
        assertEq(prePurrBL, posPurrBL);
    }

    function test_Unstake_ShouldEmit_EventUnStake_Amount_PoolOne() public {
        uint256 amountStake = initBalance;
        uint256 amountUnstake = 10e18;
        uint256 itemId = 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amountStake);
        purrStaking.stake(amountStake, PoolType.ONE);
        vm.stopPrank();
        (,,, uint32 preLockDay,,,,) = purrStaking.poolInfo(PoolType.ONE);

        (,, uint16 multiplier,,,,,) = purrStaking.poolInfo(PoolType.ONE);

        uint64 nextTimeStamp = uint64(block.timestamp + preLockDay + 1 seconds);
        vm.warp(nextTimeStamp);

        vm.expectEmit(true, true, true, true);
        emit UnStake(users.alice, 1, amountUnstake, (amountUnstake * multiplier) / 10, uint64(block.timestamp), PoolType.ONE);

        vm.prank(users.alice);
        purrStaking.unstake(amountUnstake, itemId);
    }

    function test_ClaimUnstakePoolOne_ShouldRevert_WhenNotEnoughTime() public {
        uint256 amountStake = initBalance;
        uint256 amountUnstake = initBalance;
        uint256 itemId = 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amountStake);
        purrStaking.stake(amountStake, PoolType.ONE);
        vm.stopPrank();

        (,,, uint32 preLockDay,,,,) = purrStaking.poolInfo(PoolType.ONE);

        uint64 nextTimeStamp = uint64(block.timestamp + preLockDay - 1 seconds);
        vm.warp(nextTimeStamp);

        vm.prank(users.alice);
        purrStaking.unstake(amountUnstake, itemId);

        bytes4 selector = bytes4(keccak256("CanNotWithClaimPoolOne()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        uint64 claimTime = uint64(block.timestamp + 10 days);
        vm.warp(claimTime);

        vm.prank(users.alice);
        purrStaking.claimUnstakePoolOne(itemId);
    }

    function test_ClaimUnstakePoolOne_ShouldRevert_WhenInvaliddItemId() public {
        uint256 amountStake = initBalance;
        uint256 amountUnstake = initBalance;
        uint256 itemId = 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amountStake);
        purrStaking.stake(amountStake, PoolType.ONE);
        vm.stopPrank();

        (,,, uint32 preLockDay,,,,) = purrStaking.poolInfo(PoolType.ONE);

        uint64 nextTimeStamp = uint64(block.timestamp + preLockDay - 1 seconds);
        vm.warp(nextTimeStamp);

        vm.prank(users.alice);
        purrStaking.unstake(amountUnstake, itemId);

        bytes4 selector = bytes4(keccak256("InvalidItemId(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 0));

        uint64 claimTime = uint64(block.timestamp + 10 days + 1 seconds);
        vm.warp(claimTime);

        vm.prank(users.alice);
        purrStaking.claimUnstakePoolOne(0);
    }

    function test_ClaimUnstakePoolOne_ShouldRevert_InvalidStaker() public {
        uint256 amount = 10e18;
        uint256 itemId = 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.ONE);
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("InvalidStaker(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.bob));
        vm.prank(users.bob);
        purrStaking.claimUnstakePoolOne(itemId);
    }

    function test_ClaimUnstakePoolOne_All_ShouldClaimUnstakePoolOneed() public {
        uint256 amountStake = initBalance;
        uint256 amountUnstake = initBalance;
        uint256 itemId = 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amountStake);
        purrStaking.stake(amountStake, PoolType.ONE);
        vm.stopPrank();

        (,,, uint32 preLockDay,,,,) = purrStaking.poolInfo(PoolType.ONE);

        uint64 nextTimeStamp = uint64(block.timestamp + preLockDay - 1 seconds);
        vm.warp(nextTimeStamp);

        vm.prank(users.alice);
        purrStaking.unstake(amountUnstake, itemId);

        (,,,, uint256 preAmountAvailable,,,,) = purrStaking.userPoolInfo(itemId);

        uint256 preAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 prePurrBL = launchPadToken.balanceOf(address(purrStaking));

        uint64 claimTime = uint64(block.timestamp + 10 days + 1 seconds);
        vm.warp(claimTime);

        vm.prank(users.alice);
        purrStaking.claimUnstakePoolOne(itemId);

        uint256 posAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 posPurrBL = launchPadToken.balanceOf(address(purrStaking));

        (,,,,, address posStaker,,,) = purrStaking.userPoolInfo(itemId);

        assertEq(posStaker, address(0));
        assertEq(purrStaking.itemIdIndexInfo(itemId), 0);

        assertEq(preAliceBL + preAmountAvailable, posAliceBL);
        assertEq(prePurrBL - preAmountAvailable, posPurrBL);
    }

    function test_ClaimUnstakePoolOne_Amount_ShouldClaimUnstakePoolOneed() public {
        uint256 amountStake = initBalance;
        uint256 amountUnstake = 10e18;
        uint256 itemId = 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amountStake);
        purrStaking.stake(amountStake, PoolType.ONE);
        vm.stopPrank();

        (,,, uint32 preLockDayStake,,,,) = purrStaking.poolInfo(PoolType.ONE);

        uint64 nextTimeStamp = uint64(block.timestamp + preLockDayStake - 1 seconds);
        vm.warp(nextTimeStamp);

        vm.prank(users.alice);
        purrStaking.unstake(amountUnstake, itemId);

        (
            uint16 preUnstakeFee,
            uint16 preApy,
            uint16 multiplier,
            uint32 preLockDay,
            uint32 preUnstakeTime,
            uint256 preTotalStaked,
            uint256 preNumberStaker,
        ) = purrStaking.poolInfo(PoolType.ONE);

        (uint64 preStartAt,, uint64 preEnd,, uint256 preAmountAvailable, address preStaker, uint256 prePPoint, uint256 preStakedAmount,) =
            purrStaking.userPoolInfo(itemId);

        uint256 preAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 prePurrBL = launchPadToken.balanceOf(address(purrStaking));

        uint64 claimTime = uint64(block.timestamp + 10 days + 1 seconds);
        vm.warp(claimTime);

        vm.prank(users.alice);
        purrStaking.claimUnstakePoolOne(itemId);

        uint256 posAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 posPurrBL = launchPadToken.balanceOf(address(purrStaking));

        (
            uint64 posStartAt,
            uint64 posUpdateAt,
            uint64 posEnd,
            uint64 posTimeUnstaked,
            uint256 posAmountAvailable,
            address posStaker,
            uint256 posPPoint,
            uint256 posStakedAmount,
        ) = purrStaking.userPoolInfo(itemId);

        (
            uint16 posUnstakeFee,
            uint16 posApy,
            ,
            uint32 posLockDay,
            uint32 posUnstakeTime,
            uint256 posTotalStaked,
            uint256 posNumberStaker,
        ) = purrStaking.poolInfo(PoolType.ONE);

        UserPoolInfo memory expectUserPool = UserPoolInfo({
            startAt: preStartAt,
            updateAt: nextTimeStamp,
            end: preEnd,
            timeUnstaked: 0,
            amountAvailable: 0,
            staker: preStaker,
            pPoint: prePPoint,
            stakedAmount: preStakedAmount,
            poolType: PoolType.ONE
        });

        PoolInfo memory expectPoolInfo = PoolInfo({
            unstakeFee: preUnstakeFee,
            apy: preApy,
            multiplier: multiplier,
            lockDay: preLockDay,
            unstakeTime: preUnstakeTime,
            totalStaked: preTotalStaked,
            numberStaker: preNumberStaker,
            poolType: PoolType.ONE
        });

        UserPoolInfo memory actualUserPool = UserPoolInfo(
            posStartAt, posUpdateAt, posEnd, posTimeUnstaked, posAmountAvailable, posStaker, posPPoint, posStakedAmount, PoolType.ONE
        );
        PoolInfo memory actualPoolInfo =
            PoolInfo(posUnstakeFee, posApy, multiplier, posLockDay, posUnstakeTime, posTotalStaked, posNumberStaker, PoolType.ONE);

        assertEq(abi.encode(expectUserPool), abi.encode(actualUserPool));
        assertEq(abi.encode(expectPoolInfo), abi.encode(actualPoolInfo));

        assertEq(preAliceBL + preAmountAvailable, posAliceBL);
        assertEq(prePurrBL - preAmountAvailable, posPurrBL);
    }

    function test_ClaimUnstakePoolOne_ShouldEmit_EventClaimUnstakePoolOne() public {
        uint256 amountStake = initBalance;
        uint256 amountUnstake = 10e18;
        uint256 itemId = 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amountStake);
        purrStaking.stake(amountStake, PoolType.ONE);
        vm.stopPrank();

        (,,, uint32 preLockDayStake,,,,) = purrStaking.poolInfo(PoolType.ONE);

        uint64 nextTimeStamp = uint64(block.timestamp + preLockDayStake - 1 seconds);
        vm.warp(nextTimeStamp);

        vm.prank(users.alice);
        purrStaking.unstake(amountUnstake, itemId);

        (,,,, uint256 preAmountAvailable,,,,) = purrStaking.userPoolInfo(itemId);

        uint64 claimTime = uint64(block.timestamp + 10 days + 1 seconds);
        vm.warp(claimTime);

        vm.expectEmit(true, true, true, true);
        emit ClaimUnstakePoolOne(users.alice, 1, preAmountAvailable, uint64(block.timestamp));

        vm.prank(users.alice);
        purrStaking.claimUnstakePoolOne(itemId);
    }

    function test_GetPendingReward_ShouldRight_PoolONE() public {
        uint256 amount = 100e18;
        uint256 itemId = 1;
        vm.warp(1);
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.ONE);
        vm.stopPrank();

        (,uint64 updateAt,,,,,,, PoolType poolType) = purrStaking.userPoolInfo(itemId);

        (, uint16 apy,,,,,,) = purrStaking.poolInfo(poolType);

        vm.warp(365 days + 1 seconds);
        uint256 timeStaked = block.timestamp - updateAt;
        uint256 expectTimeStaked = 365 days + 1 seconds - 1 seconds;
        assertEq(timeStaked, expectTimeStaked);

        uint256 timeStakedMulApy = expectTimeStaked * apy;
        uint256 div = 10_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward = amount.mulDiv(timeStakedMulApy, div, Math.Rounding.Floor);

        uint256 actualReward = purrStaking.getPendingReward(1);

        assertEq(expectReward, actualReward);
    }

    function test_GetPendingReward_ShouldRight_PoolTWO() public {
        uint256 amount = 100e18;
        uint256 itemId = 1;
        vm.warp(1);
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.TWO);
        vm.stopPrank();

        (,uint64 updateAt,,,,,,, PoolType poolType) = purrStaking.userPoolInfo(itemId);

        (, uint16 apy,,,,,,) = purrStaking.poolInfo(poolType);

        vm.warp(365 days + 1 seconds);
        uint256 timeStaked = block.timestamp - updateAt;
        uint256 expectTimeStaked = 365 days + 1 seconds - 1 seconds;
        assertEq(timeStaked, expectTimeStaked);

        uint256 timeStakedMulApy = expectTimeStaked * apy;
        uint256 div = 10_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward = amount.mulDiv(timeStakedMulApy, div, Math.Rounding.Floor);

        uint256 actualReward = purrStaking.getPendingReward(1);

        assertEq(expectReward, actualReward);
    }

    function test_GetPendingReward_ShouldRight_PoolThree() public {
        uint256 amount = 100e18;
        uint256 itemId = 1;
        vm.warp(1);
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.THREE);
        vm.stopPrank();

        (,uint64 updateAt,,,,,,, PoolType poolType) = purrStaking.userPoolInfo(itemId);

        (, uint16 apy,,,,,,) = purrStaking.poolInfo(poolType);

        vm.warp(365 days + 1 seconds);
        uint256 timeStaked = block.timestamp - updateAt;
        uint256 expectTimeStaked = 365 days + 1 seconds - 1 seconds;
        assertEq(timeStaked, expectTimeStaked);

        uint256 timeStakedMulApy = expectTimeStaked * apy;
        uint256 div = 10_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward = amount.mulDiv(timeStakedMulApy, div, Math.Rounding.Floor);

        uint256 actualReward = purrStaking.getPendingReward(1);

        assertEq(expectReward, actualReward);
    }

    function test_GetPendingReward_ShouldRight_PoolFour() public {
        uint256 amount = 100e18;
        uint256 itemId = 1;
        vm.warp(1);
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.FOUR);
        vm.stopPrank();

        (,uint64 updateAt,,,,,,, PoolType poolType) = purrStaking.userPoolInfo(itemId);

        (, uint16 apy,,,,,,) = purrStaking.poolInfo(poolType);

        vm.warp(365 days + 1 seconds);
        uint256 timeStaked = block.timestamp - updateAt;
        uint256 expectTimeStaked = 365 days + 1 seconds - 1 seconds;
        assertEq(timeStaked, expectTimeStaked);

        uint256 timeStakedMulApy = expectTimeStaked * apy;
        uint256 div = 10_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward = amount.mulDiv(timeStakedMulApy, div, Math.Rounding.Floor);

        uint256 actualReward = purrStaking.getPendingReward(1);

        assertEq(expectReward, actualReward);
    }

    function test_GetTotalReward_ShouldRight_PoolONE() public {
        uint256 amount = 100e18;
        uint256 itemId = 1;
        vm.warp(1);
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.ONE);
        vm.stopPrank();

        (uint64 startAt,,uint64 end,,,,,, PoolType poolType) = purrStaking.userPoolInfo(itemId);

        (, uint16 apy,,,,,,) = purrStaking.poolInfo(poolType);

        uint256 timeStaked = end - startAt;
        uint256 expectTimeStaked = 30 days + 1 seconds - 1 seconds;
        assertEq(timeStaked, expectTimeStaked);

        uint256 timeStakedMulApy = expectTimeStaked * apy;
        uint256 div = 10_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward = amount.mulDiv(timeStakedMulApy, div, Math.Rounding.Floor);

        uint256 actualReward = purrStaking.getTotalReward(1);

        assertEq(expectReward, actualReward);
    }

    function test_GetTotalReward_ShouldRight_PoolTWO() public {
        uint256 amount = 100e18;
        uint256 itemId = 1;
        vm.warp(1);
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.TWO);
        vm.stopPrank();

        (uint64 startAt,,uint64 end,,,,,, PoolType poolType) = purrStaking.userPoolInfo(itemId);

        (, uint16 apy,,,,,,) = purrStaking.poolInfo(poolType);

        uint256 timeStaked = end - startAt;
        uint256 expectTimeStaked = 60 days + 1 seconds - 1 seconds;
        assertEq(timeStaked, expectTimeStaked);

        uint256 timeStakedMulApy = expectTimeStaked * apy;
        uint256 div = 10_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward = amount.mulDiv(timeStakedMulApy, div, Math.Rounding.Floor);

        uint256 actualReward = purrStaking.getTotalReward(1);

        assertEq(expectReward, actualReward);
    }

    function test_GetTotalReward_ShouldRight_PoolThree() public {
        uint256 amount = 100e18;
        uint256 itemId = 1;
        vm.warp(1);
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.THREE);
        vm.stopPrank();

        (uint64 startAt,,uint64 end,,,,,, PoolType poolType) = purrStaking.userPoolInfo(itemId);

        (, uint16 apy,,,,,,) = purrStaking.poolInfo(poolType);

        uint256 timeStaked = end - startAt;
        uint256 expectTimeStaked = 150 days + 1 seconds - 1 seconds;
        assertEq(timeStaked, expectTimeStaked);

        uint256 timeStakedMulApy = expectTimeStaked * apy;
        uint256 div = 10_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward = amount.mulDiv(timeStakedMulApy, div, Math.Rounding.Floor);

        uint256 actualReward = purrStaking.getTotalReward(1);

        assertEq(expectReward, actualReward);
    }

    function test_GetTotalReward_ShouldRight_PoolFour() public {
        uint256 amount = 100e18;
        uint256 itemId = 1;
        vm.warp(1);
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.FOUR);
        vm.stopPrank();

        (uint64 startAt,,uint64 end,,,,,, PoolType poolType) = purrStaking.userPoolInfo(itemId);

        (, uint16 apy,,,,,,) = purrStaking.poolInfo(poolType);

        uint256 timeStaked = end - startAt;
        uint256 expectTimeStaked = 240 days + 1 seconds - 1 seconds;
        assertEq(timeStaked, expectTimeStaked);

        uint256 timeStakedMulApy = expectTimeStaked * apy;
        uint256 div = 10_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward = amount.mulDiv(timeStakedMulApy, div, Math.Rounding.Floor);

        uint256 actualReward = purrStaking.getTotalReward(1);

        assertEq(expectReward, actualReward);
    }

    function test_ClaimReward_ShouldRevert_WhenInvalidStaker() public {
        uint256 amount = 100e18;
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.THREE);
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("InvalidStaker(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.bob));

        vm.prank(users.bob);
        purrStaking.claimReward(1);
    }

    function test_ClaimReward_ShouldRevert_WhenInsufficientBalance() public {
        uint256 amount = 100e18;
        uint256 itemId = 1;
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.THREE);
        vm.stopPrank();

        vm.startPrank(address(purrStaking));
        launchPadToken.transfer(users.maker, amount + initBalance);
        vm.stopPrank();

        vm.warp(1000 days);
        bytes4 selector = bytes4(keccak256("InsufficientBalance(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, launchPadToken.balanceOf(address(purrStaking))));

        vm.prank(users.alice);
        purrStaking.claimReward(itemId);
    }

    function test_ClaimReward_ShouldClaimRewarded() public {
        uint256 amount = 100e18;
        uint256 prePurrBL = launchPadToken.balanceOf(address(purrStaking));
        uint256 preAliceBL = launchPadToken.balanceOf(users.alice);
        uint256 itemId = 1;

        vm.warp(1 seconds);
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.ONE);
        vm.stopPrank();

        vm.warp(32 days);

        uint256 currentPendingReward = purrStaking.getPendingReward(1);
        vm.prank(users.alice);
        purrStaking.claimReward(itemId);

        (,uint64 updateAt,,,,,,,) = purrStaking.userPoolInfo(itemId);

        uint256 posPurrBL = launchPadToken.balanceOf(address(purrStaking));
        uint256 posAliceBL = launchPadToken.balanceOf(users.alice);

        assertEq(posAliceBL + amount - preAliceBL, currentPendingReward);
        assertEq(prePurrBL + amount - posPurrBL, currentPendingReward);
        assertEq(updateAt, 32 days);
    }

    function test_ClaimReward_ShouldEmit_EventClaimPendingReward() public {
        uint256 amount = 100e18;
        uint256 itemId = 1;

        vm.warp(1 seconds);
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.ONE);
        vm.stopPrank();

        vm.warp(32 days);

        uint256 currentPendingReward = purrStaking.getPendingReward(1);

        vm.expectEmit(true, true, true, true);
        emit ClaimPendingReward(users.alice, 1, currentPendingReward, uint64(block.timestamp));

        vm.prank(users.alice);
        purrStaking.claimReward(itemId);
    }

    function test_UpdatePool_ShouldRevert_WhenNotOwner() public {
        PoolInfo memory pool4 = PoolInfo({
            apy: 2500,
            unstakeFee: 300,
            multiplier: 2,
            lockDay: 240 days,
            unstakeTime: 0,
            totalStaked: 0,
            numberStaker: 0,
            poolType: PoolType.FOUR
        });

        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrStaking.updatePool(pool4);
    }

    function test_UpdatePool_ShouldUpdatePooled() public {
        PoolInfo memory expectPool = PoolInfo({
            apy: 2500,
            unstakeFee: 300,
            multiplier: 2,
            lockDay: 240 days,
            unstakeTime: 0,
            totalStaked: 0,
            numberStaker: 0,
            poolType: PoolType.FOUR
        });

        vm.prank(users.admin);
        purrStaking.updatePool(expectPool);
        (
            uint16 unstakeFee,
            uint16 apy,
            uint16 multiplier,
            uint32 lockDay,
            uint32 unstakeTime,
            uint256 totalStaked,
            uint256 numberStaker,
            PoolType poolType
        ) = purrStaking.poolInfo(PoolType.FOUR);

        PoolInfo memory actualPool = PoolInfo({
            apy: apy,
            unstakeFee: unstakeFee,
            multiplier: multiplier,
            lockDay: lockDay,
            unstakeTime: unstakeTime,
            totalStaked: totalStaked,
            numberStaker: numberStaker,
            poolType: poolType
        });

        assertEq(abi.encode(expectPool), abi.encode(actualPool));
    }

    function test_UpdatePool_EmitEvent_UpdatePool() public {
        PoolInfo memory expectPool = PoolInfo({
            apy: 2500,
            unstakeFee: 300,
            multiplier: 2,
            lockDay: 240 days,
            unstakeTime: 0,
            totalStaked: 0,
            numberStaker: 0,
            poolType: PoolType.FOUR
        });

        vm.prank(users.admin);
        purrStaking.updatePool(expectPool);

        vm.expectEmit(true, true, true, true);
        emit UpdatePool(expectPool);

        vm.prank(users.admin);
        purrStaking.updatePool(expectPool);
    }

    function test_UpdateTier_ShouldRevert_WhenNotOwner() public {
        TierInfo memory tier1 = TierInfo({ lotteryProbabilities: 612, poolWeight: 1, pPoint: 1000, tierType: TierType.TWO });

        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrStaking.updateTier(tier1);
    }

    function test_UpdateTier_ShouldUpdateTiered() public {
        TierInfo memory expectTier = TierInfo({ lotteryProbabilities: 612, poolWeight: 1, pPoint: 1000, tierType: TierType.TWO });

        vm.prank(users.admin);
        purrStaking.updateTier(expectTier);
        (uint16 lotteryProbabilities, uint16 poolWeight, uint256 pPoint, TierType tierType) = purrStaking.tierInfo(TierType.TWO);
        TierInfo memory actualTier =
            TierInfo({ lotteryProbabilities: lotteryProbabilities, poolWeight: poolWeight, pPoint: pPoint, tierType: tierType });

        assertEq(abi.encode(expectTier), abi.encode(actualTier));
    }

    function test_UpdateTier_EmitEvent_UpdateTier() public {
        TierInfo memory expectTier = TierInfo({ lotteryProbabilities: 612, poolWeight: 1, pPoint: 1000, tierType: TierType.TWO });

        vm.expectEmit(true, true, true, true);
        emit UpdateTier(expectTier);

        vm.prank(users.admin);
        purrStaking.updateTier(expectTier);
    }

    function test_AddFund_ShouldAddFunded() public {
        uint256 amount = 10e18;

        uint256 prePurrBL = launchPadToken.balanceOf(address(purrStaking));
        uint256 preAdminBL = launchPadToken.balanceOf(users.admin);

        vm.startPrank(users.admin);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.addFund(amount);
        vm.stopPrank();

        uint256 posPurrBL = launchPadToken.balanceOf(address(purrStaking));
        uint256 posAdminBL = launchPadToken.balanceOf(users.admin);

        assertEq(prePurrBL + amount, posPurrBL);
        assertEq(preAdminBL - amount, posAdminBL);
    }

    function test_GetTotalStakedPool_ShouldGetTotalStakedPool() public {
        _deal(users.carole, 100e18);
        _deal(users.maker, 100e18);
        _deal(address(3), 100e18);

        uint256 amount = 10e18;
        vm.warp(1);
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.ONE);
        vm.stopPrank();

        (,uint64 updateAt1,,,,,,, PoolType poolType1) = purrStaking.userPoolInfo(1);

        (, uint16 _apy1,,,,,,) = purrStaking.poolInfo(poolType1);

        vm.warp(365 days + 1 seconds);
        uint256 timeStaked1 = block.timestamp - updateAt1;
        uint256 expectTimeStaked1 = 365 days + 1 seconds - 1 seconds;
        assertEq(timeStaked1, expectTimeStaked1);

        uint256 timeStakedMulApy1 = expectTimeStaked1 * _apy1;
        uint256 div1 = 10_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward1 = amount.mulDiv(timeStakedMulApy1, div1, Math.Rounding.Floor);

        uint256 actualReward1 = purrStaking.getPendingReward(1);

        assertEq(expectReward1, actualReward1);
        /////////////////////////////////////

        vm.warp(1);
        vm.startPrank(users.bob);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.TWO);
        vm.stopPrank();

        (,uint64 _updateAt2,,,,,,, PoolType _poolType2) = purrStaking.userPoolInfo(2);

        (, uint16 _apy2,,,,,,) = purrStaking.poolInfo(_poolType2);

        vm.warp(365 days + 1 seconds);
        uint256 timeStaked2 = block.timestamp - _updateAt2;
        uint256 expectTimeStaked2 = 365 days + 1 seconds - 1 seconds;
        assertEq(timeStaked2, expectTimeStaked2);

        uint256 timeStakedMulApy2 = expectTimeStaked2 * _apy2;
        uint256 div2 = 10_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward2 = amount.mulDiv(timeStakedMulApy2, div2, Math.Rounding.Floor);

        uint256 actualReward2 = purrStaking.getPendingReward(2);

        assertEq(expectReward2, actualReward2);
        ////////////////////////////////////

        vm.warp(1);
        vm.startPrank(users.bob);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.THREE);
        vm.stopPrank();

        (,uint64 _updateAt3,,,,,,, PoolType _poolType3) = purrStaking.userPoolInfo(3);

        (, uint16 _apy3,,,,,,) = purrStaking.poolInfo(_poolType3);

        vm.warp(365 days + 1 seconds);
        uint256 timeStaked3 = block.timestamp - _updateAt3;
        uint256 expectTimeStaked3 = 365 days + 1 seconds - 1 seconds;
        assertEq(timeStaked3, expectTimeStaked3);

        uint256 timeStakedMulApy3 = expectTimeStaked3 * _apy3;
        uint256 div3 = 10_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward3 = amount.mulDiv(timeStakedMulApy3, div3, Math.Rounding.Floor);

        uint256 actualReward3 = purrStaking.getPendingReward(3);

        assertEq(expectReward3, actualReward3);
        //////////////////////////////////

        vm.warp(1);
        vm.startPrank(users.maker);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.FOUR);
        vm.stopPrank();

        (,uint64 _updateAt4,,,,,,, PoolType _poolType4) = purrStaking.userPoolInfo(4);

        (, uint16 _apy4,,,,,,) = purrStaking.poolInfo(_poolType4);

        vm.warp(365 days + 1 seconds);
        uint256 timeStaked4 = block.timestamp - _updateAt4;
        uint256 expectTimeStaked4 = 365 days + 1 seconds - 1 seconds;
        assertEq(timeStaked4, expectTimeStaked4);

        uint256 timeStakedMulApy4 = expectTimeStaked4 * _apy4;
        uint256 div4 = 10_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward4 = amount.mulDiv(timeStakedMulApy4, div4, Math.Rounding.Floor);

        uint256 actualReward4 = purrStaking.getPendingReward(4);

        assertEq(expectReward4, actualReward4);
        //////////////////////////

        vm.warp(1);
        vm.startPrank(address(3));
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.THREE);
        vm.stopPrank();

        (,uint64 _updateAt5,,,,,,, PoolType _poolType5) = purrStaking.userPoolInfo(5);

        (, uint16 _apy5,,,,,,) = purrStaking.poolInfo(_poolType5);

        vm.warp(365 days + 1 seconds);
        uint256 timeStaked5 = block.timestamp - _updateAt5;
        uint256 expectTimeStaked5 = 365 days + 1 seconds - 1 seconds;
        assertEq(timeStaked5, expectTimeStaked5);

        uint256 timeStakedMulApy5 = expectTimeStaked5 * _apy5;
        uint256 div5 = 10_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward5 = amount.mulDiv(timeStakedMulApy5, div5, Math.Rounding.Floor);

        uint256 actualReward5 = purrStaking.getPendingReward(5);

        assertEq(expectReward5, actualReward5);

        uint256 totalExpectReward = expectReward1 + expectReward2 + expectReward3 + expectReward4 + expectReward5;

        uint256 totalApy = _apy1 + _apy2 + _apy3 + _apy4;
        uint256 avgAPY = totalApy / 4;

        (uint256 _totalStaked, uint256 _totalNumberStaker, uint256 _totalReward, uint256 _avgAPY) =
            purrStaking.getTotalStakedPool();

        uint256 _itemId = 5;
        assertEq(_itemId, purrStaking.itemId());
        assertEq(_totalStaked, 50e18);
        assertEq(_totalNumberStaker, 5);
        assertEq(_totalReward, totalExpectReward);
        assertEq(_avgAPY, avgAPY);
    }

    function test_GetUserTotalStaked_ShouldRight() public {
        uint256 amount1 = 12 * 1_000_000_000_000_000_012;
        uint256 amount2 = 12 * 1_000_300_000_000_002_012;
        uint256 amount3 = 12 * 1_000_056_000_000_500_012;
        uint256 amount4 = 12 * 1_000_251_000_000_000_111;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount1);
        purrStaking.stake(amount1, PoolType.ONE);

        launchPadToken.approve(address(purrStaking), amount2);
        purrStaking.stake(amount2, PoolType.TWO);

        launchPadToken.approve(address(purrStaking), amount3);
        purrStaking.stake(amount3, PoolType.THREE);

        launchPadToken.approve(address(purrStaking), amount4);
        purrStaking.stake(amount4, PoolType.FOUR);

        (uint256 actualTotalStake, uint256 actualPoint,,) = purrStaking.getUserTotalStaked(users.alice);
        vm.stopPrank();

        (,, uint16 multiplier1,,,,,) = purrStaking.poolInfo(PoolType.ONE);
        (,, uint16 multiplier2,,,,,) = purrStaking.poolInfo(PoolType.TWO);
        (,, uint16 multiplier3,,,,,) = purrStaking.poolInfo(PoolType.THREE);
        (,, uint16 multiplier4,,,,,) = purrStaking.poolInfo(PoolType.FOUR);
        uint256 expectTotalStake = amount1 + amount2 + amount3 + amount4;
        uint256 expectPoint = (amount1 * multiplier1 + amount2 * multiplier2 + amount3 * multiplier3 + amount4 * multiplier4) / 10;

        assertEq(actualTotalStake, expectTotalStake);
        assertEq(actualPoint, expectPoint);
    }

    function test_GetUserItemId_ShouldRight() public {
        uint256 amount = 10e18;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.ONE);

        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.TWO);

        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.THREE);

        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.FOUR);

        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.ONE);
        uint256[] memory actualItemIds = purrStaking.getUserItemId(users.alice);

        vm.stopPrank();
        itemIds.push(1);
        itemIds.push(2);
        itemIds.push(3);
        itemIds.push(4);
        itemIds.push(5);

        assertEq(itemIds, actualItemIds);
    }

    function test_WithDrawFund_ShouldWithDrawFunded() public {
        uint256 amount = 10e18;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.ONE);

        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.TWO);

        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.THREE);

        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.FOUR);

        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.ONE);

        vm.stopPrank();

        uint256 preAdminBL = launchPadToken.balanceOf(users.admin);
        uint256 prePurrBL = launchPadToken.balanceOf(address(purrStaking));

        vm.prank(users.admin);
        purrStaking.withdrawFund(amount);

        uint256 posAdminBL = launchPadToken.balanceOf(users.admin);
        uint256 posPurrBL = launchPadToken.balanceOf(address(purrStaking));

        assertEq(preAdminBL + amount, posAdminBL);
        assertEq(prePurrBL - amount, posPurrBL);
    }

    function test_WithdrawFund_ShouldRevert_WhenInvalidAmount() public {
        uint256 amount = 10e18;
        uint256 purrBL = launchPadToken.balanceOf(address(purrStaking));
        uint256 amountWithDraw = purrBL + 1;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.ONE);
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("InvalidAmount(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, amountWithDraw));

        vm.prank(users.admin);
        purrStaking.withdrawFund(amountWithDraw);
    }

    function test_Pause_ShouldRevert_WhenPause() public {
        vm.prank(users.admin);
        purrStaking.pause();

        uint256 amount = 100e18;
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);

        bytes4 selector = bytes4(keccak256("EnforcedPause()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        purrStaking.stake(amount, PoolType.THREE);
        vm.stopPrank();
    }

    function _initPools() internal {
        PoolInfo memory pool1 = PoolInfo({
            unstakeFee: 0,
            apy: 900,
            multiplier: 10,
            lockDay: 30 days,
            unstakeTime: 10 days,
            totalStaked: 0,
            numberStaker: 0,
            poolType: PoolType.ONE
        });
        PoolInfo memory pool2 = PoolInfo({
            unstakeFee: 1000,
            apy: 1200,
            multiplier: 15,
            lockDay: 60 days,
            unstakeTime: 0,
            totalStaked: 0,
            numberStaker: 0,
            poolType: PoolType.TWO
        });
        PoolInfo memory pool3 = PoolInfo({
            unstakeFee: 2000,
            apy: 1600,
            multiplier: 20,
            lockDay: 150 days,
            unstakeTime: 0,
            totalStaked: 0,
            numberStaker: 0,
            poolType: PoolType.THREE
        });
        PoolInfo memory pool4 = PoolInfo({
            unstakeFee: 3000,
            apy: 2100,
            multiplier: 25,
            lockDay: 240 days,
            unstakeTime: 0,
            totalStaked: 0,
            numberStaker: 0,
            poolType: PoolType.FOUR
        });
        poolInfos.push(pool1);
        poolInfos.push(pool2);
        poolInfos.push(pool3);
        poolInfos.push(pool4);
    }

    function _initTiers() internal {
        TierInfo memory tier1 = TierInfo({ lotteryProbabilities: 612, poolWeight: 1, pPoint: 1000, tierType: TierType.ONE });
        TierInfo memory tier2 = TierInfo({ lotteryProbabilities: 2534, poolWeight: 1, pPoint: 4000, tierType: TierType.TWO });
        TierInfo memory tier3 = TierInfo({ lotteryProbabilities: 5143, poolWeight: 1, pPoint: 10_000, tierType: TierType.THREE });
        TierInfo memory tier4 = TierInfo({ lotteryProbabilities: 7813, poolWeight: 2, pPoint: 30_000, tierType: TierType.FOUR });
        TierInfo memory tier5 = TierInfo({ lotteryProbabilities: 9553, poolWeight: 5, pPoint: 60_000, tierType: TierType.FIVE });
        TierInfo memory tier6 =
            TierInfo({ lotteryProbabilities: 10_000, poolWeight: 10, pPoint: 100_000, tierType: TierType.SIX });

        tierInfos.push(tier1);
        tierInfos.push(tier2);
        tierInfos.push(tier3);
        tierInfos.push(tier4);
        tierInfos.push(tier5);
        tierInfos.push(tier6);
    }

    function _deal(address _reciever, uint256 _amount) internal {
        vm.prank(users.admin);
        launchPadToken.mint(_reciever, _amount);
    }
}
