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
    
    // apr * 100.000
    // multiplier * 10

    PoolInfo memory pool1 = createPoolInfo(1000, 0, 10, 30 days, 10, 0, 0, PoolType.ONE);
    vm.prank(users.admin);
    purrStaking.updatePool(pool1);

    PoolInfo memory pool2 = createPoolInfo(3000, 10, 15, 60 days, 0, 0, 0, PoolType.TWO);
    vm.prank(users.admin);
    purrStaking.updatePool(pool2);

    PoolInfo memory pool3 = createPoolInfo(9000, 20, 20, 120 days, 0, 0, 0, PoolType.THREE);
    vm.prank(users.admin);
    purrStaking.updatePool(pool3);

    PoolInfo memory pool4 = createPoolInfo(15000, 30, 25, 240 days, 0, 0, 0, PoolType.FOUR);
    vm.prank(users.admin);
    purrStaking.updatePool(pool4);
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

  function test_Expect_UpdatePool() view public{
    PoolInfo memory pool3 = createPoolInfo(9000, 20, 20, 120 days, 0, 0, 0, PoolType.THREE);
    
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
    assertEq(abi.encode(pool3), abi.encode(retrievedPool));
  }

  function test_Expect_EmitEvent_UpdatePool() public{
    PoolInfo memory pool = createPoolInfo(9000, 20, 20, 120 days, 0, 0, 0, PoolType.THREE);

    vm.expectEmit(true, false, false, true);
    emit UpdatePool(pool);

    vm.prank(users.admin);
    purrStaking.updatePool(pool);
  }

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
    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30);
    purrStaking.stake(30, PoolType.THREE);
    vm.stopPrank();

    (, , , , , uint256 _totalStaked, uint256 _numberStaker, ) = purrStaking.poolInfo(PoolType.THREE);

    assertEq(_totalStaked, 30);
    assertEq(_numberStaker, 1);
    assertEq(purrStaking.itemId(), 1);
  }

  function test_Expert_UserPoolInfo_Stake() public {
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
      pPoint: 30 * 20,
      stakedAmount: 30,
      start: block.timestamp,
      end: block.timestamp + 120 days,
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
    dealTokens(launchPadToken, users.alice);

    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30);

    vm.expectEmit(true, true, false, true);
    emit Stake(users.alice, 1, 30, 600, block.timestamp, block.timestamp + 120 days, PoolType.THREE);

    purrStaking.stake(30, PoolType.THREE);
    vm.stopPrank();
  }


  function test_ShouldRevert_InvalidStaker_claimReward() public {
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

  function test_Expect_PoolONE_CalculatePendingReward() public {
    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30 * 1e18);
    purrStaking.stake(30 * 1e18, PoolType.ONE);
    vm.stopPrank();

    assertEq(purrStaking.itemId(), 1);

    ( , , uint256 _stakedAmount, uint256 _start, , PoolType _pool_Type) = purrStaking.userPoolInfo(1);

    (uint16 _apr, , , , , , , ) = purrStaking.poolInfo(_pool_Type);

    vm.warp(32 days);
    uint256 timeStaked = block.timestamp - _start;
    uint256 timeStakedMulApr = timeStaked * _apr;
    uint256 div = 100000 * purrStaking.SECOND_YEAR();
    uint256 _reward = _stakedAmount.mulDiv(timeStakedMulApr, div, Math.Rounding.Floor);

    vm.warp(32 days);
    uint256 reward = purrStaking.getPendingReward(1);

    assertEq(_reward, reward);
    assertEq(26301360350076103, reward);
  }  

  function test_Expect_HandlePoolONE_CalculatePendingReward() public {
    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30 * 1e18);
    purrStaking.stake(30 * 1e18, PoolType.ONE);
    vm.stopPrank();

    assertEq(purrStaking.itemId(), 1);

    ( , , uint256 _stakedAmount, uint256 _start, , PoolType _pool_Type) = purrStaking.userPoolInfo(1);

    (uint16 _apr, , , , , , , ) = purrStaking.poolInfo(_pool_Type);

    vm.warp(32 days);
    uint256 timeStaked = block.timestamp - _start;
    uint256 timeStakedMulApr = timeStaked * _apr;
    uint256 div = 100000 * purrStaking.SECOND_YEAR();

    uint256 _reward = (_stakedAmount * timeStakedMulApr) / div;

    vm.warp(32 days);
    uint256 reward = purrStaking.getPendingReward(1);

    assertEq(_reward, reward);
    assertEq(26301360350076103, reward);
  }  

  function test_Expect_HandlePoolTWO_CalculatePendingReward() public {
    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30 * 1e18);
    purrStaking.stake(30 * 1e18, PoolType.TWO);
    vm.stopPrank();

    assertEq(purrStaking.itemId(), 1);

    ( , , uint256 _stakedAmount, uint256 _start, , PoolType _pool_Type) = purrStaking.userPoolInfo(1);

    (uint16 _apr, , , , , , , ) = purrStaking.poolInfo(_pool_Type);

    vm.warp(32 days);
    uint256 timeStaked = block.timestamp - _start;
    uint256 timeStakedMulApr = timeStaked * _apr;
    uint256 div = 100000 * purrStaking.SECOND_YEAR();

    uint256 _reward = (_stakedAmount * timeStakedMulApr) / div;

    vm.warp(32 days);
    uint256 reward = purrStaking.getPendingReward(1);

    assertEq(_reward, reward);
    assertEq(78904081050228310, reward);
  }  

  function test_Expect_PoolTWO_CalculatePendingReward() public {
    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30 * 1e18);
    purrStaking.stake(30 * 1e18, PoolType.TWO);
    vm.stopPrank();

    assertEq(purrStaking.itemId(), 1);

    ( , , uint256 _stakedAmount, uint256 _start, , PoolType _pool_Type) = purrStaking.userPoolInfo(1);

    (uint16 _apr, , , , , , , ) = purrStaking.poolInfo(_pool_Type);

    vm.warp(32 days);
    uint256 timeStaked = block.timestamp - _start;
    uint256 timeStakedMulApr = timeStaked * _apr;
    uint256 div = 100000 * purrStaking.SECOND_YEAR();

    uint256 _reward = _stakedAmount.mulDiv(timeStakedMulApr, div, Math.Rounding.Floor);

    vm.warp(32 days);
    uint256 reward = purrStaking.getPendingReward(1);

    assertEq(_reward, reward);
    assertEq(78904081050228310, reward);
  }  

  function test_Expect_PoolTHREE_CalculatePendingReward() public {
    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30 * 1e18);
    purrStaking.stake(30 * 1e18, PoolType.THREE);
    vm.stopPrank();

    assertEq(purrStaking.itemId(), 1);

    ( , , uint256 _stakedAmount, uint256 _start, , PoolType _pool_Type) = purrStaking.userPoolInfo(1);

    (uint16 _apr, , , , , , , ) = purrStaking.poolInfo(_pool_Type);

    vm.warp(32 days);
    uint256 timeStaked = block.timestamp - _start;
    uint256 timeStakedMulApr = timeStaked * _apr;
    uint256 div = 100000 * purrStaking.SECOND_YEAR();

    uint256 _reward = _stakedAmount.mulDiv(timeStakedMulApr, div, Math.Rounding.Floor);

    vm.warp(32 days);
    uint256 reward = purrStaking.getPendingReward(1);

    assertEq(_reward, reward);
    assertEq(236712243150684931, reward);
  }  

  function test_Expect_PoolFOUR_CalculatePendingReward() public {
    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30 * 1e18);
    purrStaking.stake(30 * 1e18, PoolType.FOUR);
    vm.stopPrank();

    assertEq(purrStaking.itemId(), 1);

    ( , , uint256 _stakedAmount, uint256 _start, , PoolType _pool_Type) = purrStaking.userPoolInfo(1);

    (uint16 _apr, , , , , , , ) = purrStaking.poolInfo(_pool_Type);

    vm.warp(32 days);
    uint256 timeStaked = block.timestamp - _start;
    uint256 timeStakedMulApr = timeStaked * _apr;
    uint256 div = 100000 * purrStaking.SECOND_YEAR();

    uint256 _reward = _stakedAmount.mulDiv(timeStakedMulApr, div, Math.Rounding.Floor);

    vm.warp(32 days);
    uint256 reward = purrStaking.getPendingReward(1);

    assertEq(_reward, reward);
    assertEq(394520405251141552, reward);
  }  

  function test_Expect_Balance() public {
    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30 * 1e18);
    purrStaking.stake(30 * 1e18, PoolType.ONE);
    vm.stopPrank();

    assertEq(launchPadToken.balanceOf(address(purrStaking)), 30 * 1e18);
  }

  function test_ShouldRevert_InsufficientBalance_ClaimReward() public {
    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30 * 1e18);
    purrStaking.stake(30 * 1e18, PoolType.ONE);
    vm.stopPrank();

    assertEq(launchPadToken.balanceOf(address(purrStaking)), 30 * 1e18);

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

  function test_Expect_ClaimReward() public {
    dealTokens(launchPadToken, users.alice);
    vm.startPrank(users.alice);
    launchPadToken.approve(address(purrStaking), 30 * 1e18);
    purrStaking.stake(30 * 1e18, PoolType.ONE);
    vm.stopPrank();

    vm.prank(address(purrStaking));
    launchPadToken.approve(address(purrStaking), 30 * 1e18);
    
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