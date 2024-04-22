// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { BaseTest } from "../Base.t.sol";
import { console } from "forge-std/console.sol";

import { UserPoolInfo, PoolInfo, PoolType, TierType, TierInfo } from "../../src/types/PurrStaingType.sol";
import { PurrToken } from "../../src/token/PurrToken.sol";
import { PurrStaking } from "../../src/PurrStaking.sol";

contract PurrStakingTest is BaseTest {
    using Math for uint256;

    PurrStaking purrStaking;
    PurrToken launchPadToken;
    PoolInfo[] poolInfos;
    TierInfo[] tierInfos;
    uint256 initBalance;

     event Stake(
        address indexed staker,
        uint256 indexed itemId,
        uint256 amount,
        uint256 point,
        uint64 updateAt,
        uint64 end,
        PoolType poolType
    );

    event UpdatePool(PoolInfo pool);

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
    }

    function test_Stake_ShouldRevert_WhenInvalidAmount() public {
        uint256 amount = 0;
        bytes4 selector = bytes4(keccak256("InvalidAmount(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, amount));

        vm.prank(users.alice);
        purrStaking.stake(amount, PoolType.THREE);
    }

    // function test_Stake_ShouldRevert_WhenInvalidPoolType() public {
    //     PoolType
    // }
    // need test for multiple  staker
    function test_Stake_ShouldStaked() public {
        uint256 amount = 100e18;

        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.THREE);
        vm.stopPrank();
        (,, uint16 multiplier, uint32 lockDay,, uint256 totalStaked, uint256 numberStaker,) = purrStaking.poolInfo(PoolType.THREE);
        (
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

        assertEq(updateAt, block.timestamp);
        assertEq(end, block.timestamp + lockDay);
        assertEq(timeUnstaked, 0);
        assertEq(amountAvailable, 0);
        assertEq(staker, users.alice);
        assertEq(pPoint, pointExpect);
        assertEq(stakedAmount, amount);
        assertEq(uint8(poolType), uint8(PoolType.THREE));
        vm.prank(users.alice);
        assertEq(purrStaking.getUserItemId()[0], 1);
        assertEq(launchPadToken.balanceOf(users.alice), initBalance - amount);
        uint256 posPurrBL  = amount + initBalance; 
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
            users.alice, purrStaking.itemId() + 1, amount, pointExpect, uint64(block.timestamp), uint64(block.timestamp + lockDay), PoolType.FOUR
        );

        purrStaking.stake(amount, PoolType.FOUR);
        vm.stopPrank();
    }

    function test_GetPendingReward_ShouldRight_PoolONE() public {
        uint256 amount = 100e18;
        uint256 itemId = 1;
        vm.warp(1);
        vm.startPrank(users.alice);
        launchPadToken.approve(address(purrStaking), amount);
        purrStaking.stake(amount, PoolType.ONE);
        vm.stopPrank();

        (uint64 updateAt,,,,,,, PoolType poolType) = purrStaking.userPoolInfo(itemId);

        (, uint16 apr,,,,,,) = purrStaking.poolInfo(poolType);

        vm.warp(32 days);
        uint256 timeStaked = block.timestamp - updateAt;
        uint256 expectTimeStaked = 32 days - 1 seconds;
        assertEq(timeStaked, expectTimeStaked);

        uint256 timeStakedMulApr = expectTimeStaked * apr;
        uint256 div = 100_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward = amount.mulDiv(timeStakedMulApr, div, Math.Rounding.Floor);

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

        (uint64 updateAt,,,,,,, PoolType poolType) = purrStaking.userPoolInfo(itemId);

        (, uint16 apr,,,,,,) = purrStaking.poolInfo(poolType);

        vm.warp(365 days + 1 seconds);
        uint256 timeStaked = block.timestamp - updateAt;
        uint256 expectTimeStaked = 365 days + 1 seconds - 1 seconds;
        assertEq(timeStaked, expectTimeStaked);

        uint256 timeStakedMulApr = expectTimeStaked * apr;
        uint256 div = 100_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward = amount.mulDiv(timeStakedMulApr, div, Math.Rounding.Floor);

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

        (uint64 updateAt,,,,,,, PoolType poolType) = purrStaking.userPoolInfo(itemId);

        (, uint16 apr,,,,,,) = purrStaking.poolInfo(poolType);

        vm.warp(365 days + 1 seconds);
        uint256 timeStaked = block.timestamp - updateAt;
        uint256 expectTimeStaked = 365 days + 1 seconds - 1 seconds;
        assertEq(timeStaked, expectTimeStaked);

        uint256 timeStakedMulApr = expectTimeStaked * apr;
        uint256 div = 100_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward = amount.mulDiv(timeStakedMulApr, div, Math.Rounding.Floor);

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

        (uint64 updateAt,,,,,,, PoolType poolType) = purrStaking.userPoolInfo(itemId);

        (, uint16 apr,,,,,,) = purrStaking.poolInfo(poolType);

        vm.warp(365 days + 1 seconds);
        uint256 timeStaked = block.timestamp - updateAt;
        uint256 expectTimeStaked = 365 days + 1 seconds - 1 seconds;
        assertEq(timeStaked, expectTimeStaked);

        uint256 timeStakedMulApr = expectTimeStaked * apr;
        uint256 div = 100_000 * purrStaking.SECOND_YEAR();
        uint256 expectReward = amount.mulDiv(timeStakedMulApr, div, Math.Rounding.Floor);

        uint256 actualReward = purrStaking.getPendingReward(1);

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
        launchPadToken.transfer(users.maker, amount  + initBalance); 
        vm.stopPrank();
        
        vm.warp(1000 days);
        bytes4 selector = bytes4(keccak256("InsufficientBalance(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, launchPadToken.balanceOf(address(purrStaking))));

        vm.prank(users.alice);
        purrStaking.claimReward(itemId);
    }

    // function test_ClaimReward_ShouldClaimRewarded() public {
    //     uint256 amount = 100e18; 
    //     uint256 

    //     vm.startPrank(users.alice);
    //     launchPadToken.approve(address(purrStaking), amount);
    //     purrStaking.stake(amount, PoolType.ONE);
    //     vm.stopPrank();

    //     _deal(address(purrStaking), )
    //     launchPadToken.approve(address(purrStaking), 30 * 1e18);

    //     uint256 oldBalanceUser = launchPadToken.balanceOf(users.alice);
    //     uint256 oldBalancePurrStaking = launchPadToken.balanceOf(address(purrStaking));

    //     vm.warp(32 days);
    //     vm.startPrank(users.alice);
    //     purrStaking.claimReward(1);

    //     uint256 newBalanceUser = launchPadToken.balanceOf(users.alice);
    //     uint256 reward = newBalanceUser - oldBalanceUser;
    //     assertEq(reward, purrStaking.getPendingReward(1));

    //     uint256 newBalancePurrStaking = launchPadToken.balanceOf(address(purrStaking));
    //     uint256 give_reward = oldBalancePurrStaking - newBalancePurrStaking;
    //     assertEq(give_reward, purrStaking.getPendingReward(1));
    // }

    // function test_Expect_UpdatePool() public view {
    //     PoolInfo memory pool3 = createPoolInfo(9000, 20, 20, 120 days, 0, 0, 0, PoolType.THREE);

    //     (
    //         uint16 _apr,
    //         uint8 _unstakeFee,
    //         uint16 _multiplier,
    //         uint32 _lockDay,
    //         uint32 _unstakeTime,
    //         uint256 _totalStaked,
    //         uint256 _numberStaker,
    //         PoolType _poolType
    //     ) = purrStaking.poolInfo(PoolType.THREE);
    //     PoolInfo memory retrievedPool = PoolInfo({
    //         apr: _apr,
    //         unstakeFee: _unstakeFee,
    //         multiplier: _multiplier,
    //         lockDay: _lockDay,
    //         unstakeTime: _unstakeTime,
    //         totalStaked: _totalStaked,
    //         numberStaker: _numberStaker,
    //         poolType: _poolType
    //     });
    //     assertEq(abi.encode(pool3), abi.encode(retrievedPool));
    // }

    // function test_Expect_EmitEvent_UpdatePool() public {
    //     PoolInfo memory pool = createPoolInfo(9000, 20, 20, 120 days, 0, 0, 0, PoolType.THREE);

    //     vm.expectEmit(true, false, false, true);
    //     emit UpdatePool(pool);

    //     vm.prank(users.admin);
    //     purrStaking.updatePool(pool);
    // }

    function _initPools() internal {
        PoolInfo memory pool1 = PoolInfo({
            apr: 1000,
            unstakeFee: 0,
            multiplier: 10,
            lockDay: 30 days,
            unstakeTime: 10 days,
            totalStaked: 0,
            numberStaker: 0,
            poolType: PoolType.ONE
        });
        PoolInfo memory pool2 = PoolInfo({
            apr: 3000,
            unstakeFee: 1000,
            multiplier: 15,
            lockDay: 60 days,
            unstakeTime: 0,
            totalStaked: 0,
            numberStaker: 0,
            poolType: PoolType.TWO
        });
        PoolInfo memory pool3 = PoolInfo({
            apr: 9000,
            unstakeFee: 2000,
            multiplier: 20,
            lockDay: 150 days,
            unstakeTime: 0,
            totalStaked: 0,
            numberStaker: 0,
            poolType: PoolType.THREE
        });
        PoolInfo memory pool4 = PoolInfo({
            apr: 15_000,
            unstakeFee: 3000,
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
        TierInfo memory tier1 = TierInfo({ lotteryProbabilities: 612, poolWeight: 1, pPoint: 1000 });
        TierInfo memory tier2 = TierInfo({ lotteryProbabilities: 2534, poolWeight: 1, pPoint: 4000 });
        TierInfo memory tier3 = TierInfo({ lotteryProbabilities: 5143, poolWeight: 1, pPoint: 10_000 });
        TierInfo memory tier4 = TierInfo({ lotteryProbabilities: 7813, poolWeight: 2, pPoint: 30_000 });
        TierInfo memory tier5 = TierInfo({ lotteryProbabilities: 9553, poolWeight: 5, pPoint: 60_000 });
        TierInfo memory tier6 = TierInfo({ lotteryProbabilities: 10_000, poolWeight: 10, pPoint: 100_000 });

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
