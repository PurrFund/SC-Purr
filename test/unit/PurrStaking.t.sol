// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseTest } from "../Base.t.sol";
import { UserPoolInfo, PoolInfo, PoolType } from "../../src/types/PurrStaingType.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { PurrStaking } from "../../src/PurrStaking.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

contract PurrStakingTest is BaseTest {
  using Math for uint256;

  PurrStaking purrStaking;
  ERC20Mock launchPadToken;

  event Stake(
        address indexed staker,
        uint256 indexed itemId,
        uint256 amount,
        uint256 point,
        uint256 start,
        uint256 end,
        PoolType poolType
    );

  event UpdatePool(PoolInfo pool);

  function setUp() public {
    launchPadToken = new ERC20Mock("LaunchPad", "LP");
    purrStaking = new PurrStaking(address(launchPadToken), address(users.admin));
  }

  function createPoolInfo(
      uint16 _apr,
      uint8 _unstakeFee,
      uint16 _multiplier,
      uint32 _lockDay,
      uint32 _unstakeTime,
      uint256 _totalStaked,
      uint256 _numberStaker,
      PoolType _poolType
    ) internal pure returns (PoolInfo memory){
      return PoolInfo({
        apr: _apr,
        unstakeFee: _unstakeFee,
        multiplier: _multiplier,
        lockDay: _lockDay,
        unstakeTime: _unstakeTime,
        totalStaked: _totalStaked,
        numberStaker: _numberStaker,
        poolType: _poolType
      });
  }

  function test_Expect_UpdatePool() public{
    PoolInfo memory pool = createPoolInfo(2, 2, 2, 2 days, 2, 1000, 2, PoolType.THREE);
    vm.prank(users.admin);
    purrStaking.updatePool(pool);

    (uint16 _apr, uint8 _unstakeFee, uint16 _multiplier, uint32 _lockDay, uint32 _unstakeTime, uint256 _totalStaked, uint256 _numberStaker, PoolType _poolType) = purrStaking.poolInfo(PoolType.THREE);
    PoolInfo memory retrievedPool = PoolInfo({
      apr: _apr,
      unstakeFee: _unstakeFee,
      multiplier: _multiplier,
      lockDay: _lockDay,
      unstakeTime: _unstakeTime,
      totalStaked: _totalStaked,
      numberStaker: _numberStaker,
      poolType: _poolType
    });
    assertEq(abi.encode(pool), abi.encode(retrievedPool));
  }

  // function test_Expect_EmitEvent_UpdatePool() public{
  //   PoolInfo memory pool = createPoolInfo(2, 2, 2, 2 days, 2, 1000, 2, PoolType.THREE);

  //   vm.expectEmit(true, false, false, false);
  //   emit UpdatePool(pool);

  //   vm.prank(users.admin);
  //   purrStaking.updatePool(pool);
  // }

  function test_ShouldRevert_InsufficientBallance_Stake() public {
    bytes4 selector = bytes4(keccak256("InsufficientAmount(uint256)"));
    vm.expectRevert(abi.encodeWithSelector(selector, 20));
    vm.prank(users.alice);
    purrStaking.stake(20, PoolType.THREE);
  }

  function test_ShouldRevert_Amount_Staking() public {
    bytes4 selector = bytes4(keccak256("InvalidAmount(uint256)"));
    vm.expectRevert(abi.encodeWithSelector(selector, 20));
    dealTokens(launchPadToken, users.alice);
    vm.prank(users.alice);
    purrStaking.stake(0, PoolType.THREE);
  }

  function test_ShouldRevert_ERC20InsufficientAllowance_Stake() public {
    dealTokens(launchPadToken, users.alice);

    bytes4 selector = bytes4(keccak256("ERC20InsufficientAllowance(address,uint256,uint256)"));
    vm.expectRevert(abi.encodeWithSelector(selector, address(purrStaking), launchPadToken.allowance(users.alice, address(purrStaking)), 20));

    vm.prank(users.alice);
    purrStaking.stake(20, PoolType.THREE);
  }

  function test_Expect_PoolInfo_Stake() public {
    PoolInfo memory pool = createPoolInfo(2, 2, 2, 2 days, 2, 1000, 2, PoolType.THREE);
    vm.prank(users.admin);
    purrStaking.updatePool(pool);

    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30);
    purrStaking.stake(30, PoolType.THREE);
    vm.stopPrank();

    (, , , , , uint256 _totalStaked, uint256 _numberStaker, ) = purrStaking.poolInfo(PoolType.THREE);

    assertEq(_totalStaked, 1030);
    assertEq(_numberStaker, 3);
    assertEq(purrStaking.itemId(), 1);
  }

  function test_Expert_UserPoolInfo_Stake() public {
    PoolInfo memory pool = createPoolInfo(2, 2, 2, 2 days, 2, 1000, 2, PoolType.THREE);
    vm.prank(users.admin);
    purrStaking.updatePool(pool);

    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30);
    purrStaking.stake(30, PoolType.THREE);
    vm.stopPrank();

    (address _staker, uint256 _pPoint, uint256 _stakedAmount, uint256 _start, uint256 _end, PoolType _poolType) = purrStaking.userPoolInfo(1);

     UserPoolInfo memory retrievedUserPoolInfo = UserPoolInfo({
      staker: _staker,
      pPoint: _pPoint,
      stakedAmount: _stakedAmount,
      start: _start,
      end: _end,
      poolType: _poolType
    });

    UserPoolInfo memory expectUserPoolInfo = UserPoolInfo({
      staker: users.alice,
      pPoint: 30 * 2,
      stakedAmount: 30,
      start: block.timestamp,
      end: block.timestamp + 2 days,
      poolType: PoolType.THREE
    });

    assertEq(purrStaking.itemId(), 1);
    assertEq(abi.encode(retrievedUserPoolInfo), abi.encode(expectUserPoolInfo));
  }

  function test_Expect_Ballance_Stake() public {
    dealTokens(launchPadToken, users.alice);

    uint256 oldBalanceUser = launchPadToken.balanceOf(users.alice);
    uint256 oldBalancePurrStaking = launchPadToken.balanceOf(address(purrStaking));

    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30);
    purrStaking.stake(30, PoolType.THREE);
    vm.stopPrank();

    uint256 newBalanceUser = launchPadToken.balanceOf(users.alice);
    uint256 amountStake = oldBalanceUser - newBalanceUser;

    uint256 newBalancePurrStaking = launchPadToken.balanceOf(address(purrStaking));
    uint256 _amountStake = newBalancePurrStaking - oldBalancePurrStaking;

    assertEq(amountStake, _amountStake);
    assertEq(amountStake, 30);
    assertEq(_amountStake, 30);
  }

  function test_Expect_EmitEvent_Stake() public {
    PoolInfo memory pool = createPoolInfo(2, 2, 2, 2 days, 2, 1000, 2, PoolType.THREE);
    vm.prank(users.admin);
    purrStaking.updatePool(pool);

    dealTokens(launchPadToken, users.alice);

    
    
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30);

    vm.expectEmit(true, true, false, true);
    emit Stake(users.alice, 1, 30, 60, block.timestamp, block.timestamp + 2 days, PoolType.THREE);

    purrStaking.stake(30, PoolType.THREE);
    vm.stopPrank();
  }


  function test_ShouldRevert_InvalidStaker_claimReward() public {
    PoolInfo memory pool = createPoolInfo(1, 0, 1, 30 days, 10, 1000, 2, PoolType.ONE);
    vm.prank(users.admin);
    purrStaking.updatePool(pool);

    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30);
    purrStaking.stake(30, PoolType.THREE);
    vm.stopPrank();

    bytes4 selector = bytes4(keccak256("InvalidStaker(address)"));
    vm.expectRevert(abi.encodeWithSelector(selector, users.bob));

    vm.prank(users.bob);
    purrStaking.claimReward(1);
  }

  function test_Expect_CalculatePendingReward() public {
    PoolInfo memory pool = createPoolInfo(1, 0, 1, 30 days, 10, 1000, 2, PoolType.ONE);
    vm.prank(users.admin);
    purrStaking.updatePool(pool);

    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30);
    purrStaking.stake(30, PoolType.ONE);
    vm.stopPrank();

    assertEq(purrStaking.itemId(), 1);

    ( , , uint256 _stakedAmount, uint256 _start, , PoolType _pool_Type) = purrStaking.userPoolInfo(1);

    (uint16 _apr, , , , , , , ) = purrStaking.poolInfo(_pool_Type);

    vm.warp(32 days);
    uint256 timeStaked = block.timestamp - _start;
    uint256 timeStakedMulApr = timeStaked * _apr;
    uint256 _reward = _stakedAmount.mulDiv(timeStakedMulApr, purrStaking.SECOND_YEAR(), Math.Rounding.Floor);

    vm.warp(32 days);
    uint256 reward = purrStaking.getPendingReward(1);

    assertEq(_reward, reward);
  }  

  function test_Expect_OtherCase_CalculatePendingReward() public {
    PoolInfo memory pool = createPoolInfo(1, 0, 1, 30 days, 10, 1000, 2, PoolType.ONE);
    vm.prank(users.admin);
    purrStaking.updatePool(pool);

    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30);
    purrStaking.stake(30, PoolType.ONE);
    vm.stopPrank();

    assertEq(purrStaking.itemId(), 1);

    ( , , uint256 _stakedAmount, uint256 _start, , PoolType _pool_Type) = purrStaking.userPoolInfo(1);

    (uint16 _apr, , , , , , , ) = purrStaking.poolInfo(_pool_Type);

    vm.warp(32 days);
    uint256 timeStaked = block.timestamp - _start;
    uint256 timeStakedMulApr = timeStaked * _apr;
    uint256 _reward = (_stakedAmount * timeStakedMulApr) /purrStaking.SECOND_YEAR();

    vm.warp(32 days);
    uint256 reward = purrStaking.getPendingReward(1);

    assertEq(_reward, reward);
  }  

  function test_ShouldRevert_InsufficientBalance_ClaimReward() public {
    
    PoolInfo memory pool = createPoolInfo(1, 0, 1, 30 days, 10, 1000, 2, PoolType.ONE);
    vm.prank(users.admin);
    purrStaking.updatePool(pool);

    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30);
    purrStaking.stake(30, PoolType.ONE);
    vm.stopPrank();

    vm.startPrank(address(purrStaking));
    launchPadToken.approve(address(this), 
    launchPadToken.balanceOf(address(purrStaking)));
    vm.stopPrank();

    launchPadToken.transferFrom(address(purrStaking), users.bob, launchPadToken.balanceOf(address(purrStaking)));

    bytes4 selector = bytes4(keccak256("InsufficientBalance(uint256)"));
    vm.expectRevert(abi.encodeWithSelector(selector, launchPadToken.balanceOf(address(purrStaking))));
    
    vm.warp(32 days);
    vm.startPrank(users.alice);
    purrStaking.claimReward(1);
  }

  function test_ShouldRevert_InsufficientAllowance_ClaimReward() public {
    PoolInfo memory pool = createPoolInfo(1, 0, 1, 30 days, 10, 1000, 2, PoolType.ONE);
    vm.prank(users.admin);
    purrStaking.updatePool(pool);

    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30);
    purrStaking.stake(30, PoolType.ONE);
    vm.stopPrank();

    bytes4 selector = bytes4(keccak256("ERC20InsufficientAllowance(address,uint256,uint256)"));
    vm.expectRevert(abi.encodeWithSelector(selector, address(purrStaking), launchPadToken.allowance(address(purrStaking), address(purrStaking)), 2));
    
    vm.warp(32 days);
    vm.startPrank(users.alice);
    purrStaking.claimReward(1);
  }

  function test_Expect_ClaimReward() public {
    PoolInfo memory pool = createPoolInfo(1, 0, 1, 30 days, 10, 1000, 2, PoolType.ONE);
    vm.prank(users.admin);
    purrStaking.updatePool(pool);

    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30);
    purrStaking.stake(30, PoolType.ONE);
    vm.stopPrank();

    vm.prank(address(purrStaking));
    launchPadToken.approve(address(purrStaking), 30);
    
    uint256 oldBalanceUser = launchPadToken.balanceOf(users.alice);
    uint256 oldBalancePurrStaking = launchPadToken.balanceOf(address(purrStaking));

    vm.warp(32 days);
    vm.startPrank(users.alice);
    purrStaking.claimReward(1);

    uint256 newBalanceUser = launchPadToken.balanceOf(users.alice);
    uint256 reward = newBalanceUser - oldBalanceUser;
    assertEq(reward, purrStaking.getPendingReward(1));

    uint256 newBalancePurrStaking = launchPadToken.balanceOf(address(purrStaking));
    uint256 give_reward = oldBalancePurrStaking - newBalancePurrStaking;
    assertEq(give_reward, purrStaking.getPendingReward(1));
  }
}