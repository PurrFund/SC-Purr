// SPDX-License_Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { BaseTest } from "../Base.t.sol";
import { PurrVesting } from "../../src/PurrVesting.sol";
import { PoolState, Pool, UserPool, CreatePool } from "../../src/types/PurrVestingType.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";
import { VestingType } from "../../src/types/PurrVestingType.sol";

import { console } from "forge-std/console.sol";

contract PurrVestingTest is BaseTest {
    using Math for uint256;

    ERC20Mock erc20IDO;
    PurrVesting purrVesting;
    uint256 initBalance;
    address[] depositorAddresses;
    uint256[] amounts;
    uint64[] times;
    uint16[] percents;
    address[] _users;
    uint256[] _fundAmounts;
    address[] _usersRemove;
    uint256[] _fundAmountsRemove;

    event CreatePoolEvent(Pool pool);
    event AddFundEvent(uint256 poolId, address[] user, uint256[] fundAmount);
    event RemoveFundEvent(uint256 poolId, address[] user);
    event ClaimFundEvent(uint256 poolId, address user, uint256 fundClaimed);

    function setUp() public {
        initBalance = 100_000e18;
        purrVesting = new PurrVesting(users.admin);
        erc20IDO = new ERC20Mock("FANX", "FTK");
        _deal(users.admin, initBalance);
        amounts.push(200e18);
        amounts.push(500e18);
        amounts.push(700e18);
        depositorAddresses.push(users.alice);
        depositorAddresses.push(users.bob);
        depositorAddresses.push(users.carole);
    }

    function test_GetCurrentClaimPercent_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldRight() public {
        uint256 poolId = 1;

        times.push(uint64(block.timestamp + 100 days));
        times.push(uint64(block.timestamp + 200 days));
        times.push(uint64(block.timestamp + 300 days));

        percents.push(uint16(2000));
        percents.push(uint16(3000));
        percents.push(uint16(4000));

        CreatePool memory createPool = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST, block.timestamp + 1 days, 60 days, 1000, 0, times, percents
        );
        // - vesting type , tge , cliff, unlockpercent , linearDuration, time , percent

        vm.startPrank(users.admin);
        purrVesting.createPool(createPool);

        uint256 totalAmount;

        for (uint256 i; i < amounts.length;) {
            totalAmount += amounts[i];

            unchecked {
                ++i;
            }
        }

        erc20IDO.approve(address(purrVesting), totalAmount);

        purrVesting.addFund(poolId, amounts, depositorAddresses);

        vm.stopPrank();

        vm.warp(createPool.tge + createPool.cliff - 1);
        uint256 expectPercent1 = 0;
        assertEq(expectPercent1, purrVesting.getCurrentClaimPercent(poolId));

        vm.warp(createPool.tge + createPool.cliff);
        uint256 expectPercent2 = createPool.unlockPercent;
        uint256 actualPercent2 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent2, actualPercent2);

        vm.warp(times[0] - 1);
        uint256 expectPercent3 = createPool.unlockPercent;
        uint256 actualPercent3 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent3, actualPercent3);

        vm.warp(times[0]);
        uint256 expectPercent4 = createPool.unlockPercent + percents[0];
        uint256 actualPercent4 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent4, actualPercent4);

        vm.warp(times[1] - 1);
        uint256 expectPercent5 = createPool.unlockPercent + percents[0];
        uint256 actualPercent5 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent5, actualPercent5);

        vm.warp(times[1]);
        uint256 expectPercent6 = createPool.unlockPercent + percents[0] + percents[1];
        uint256 actualPercent6 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent6, actualPercent6);

        vm.warp(times[2] - 1);
        uint256 expectPercent7 = createPool.unlockPercent + percents[0] + percents[1];
        uint256 actualPercent7 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent7, actualPercent7);

        vm.warp(times[2]);
        uint256 expectPercent8 = 10_000;
        uint256 actualPercent8 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent8, actualPercent8);

        vm.warp(times[2] + 100 seconds);
        uint256 expectPercent9 = 10_000;
        uint256 actualPercent9 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent9, actualPercent9);
    }

    function test_GetCurrentClaimPercent_VESTING_TYPE_MILESTONE_UNLOCK_FIRST_ShouldRight() public {
        uint256 poolId = 1;

        times.push(uint64(block.timestamp + 100 days));
        times.push(uint64(block.timestamp + 200 days));
        times.push(uint64(block.timestamp + 300 days));

        percents.push(uint16(2000));
        percents.push(uint16(3000));
        percents.push(uint16(4000));

        CreatePool memory createPool = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST, block.timestamp + 1 days, 60 days, 1000, 0, times, percents
        );
        // - vesting type , tge , cliff, unlockpercent , linearDuration, time , percent

        vm.startPrank(users.admin);
        purrVesting.createPool(createPool);

        uint256 totalAmount;

        for (uint256 i; i < amounts.length;) {
            totalAmount += amounts[i];

            unchecked {
                ++i;
            }
        }

        erc20IDO.approve(address(purrVesting), totalAmount);

        purrVesting.addFund(poolId, amounts, depositorAddresses);

        vm.stopPrank();

        vm.warp(createPool.tge - 1 seconds);
        uint256 expectPercent1 = 0;
        assertEq(expectPercent1, purrVesting.getCurrentClaimPercent(poolId));

        vm.warp(createPool.tge);
        uint256 expectPercent2 = createPool.unlockPercent;
        uint256 actualPercent2 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent2, actualPercent2);

        vm.warp(createPool.tge + createPool.cliff + 1 seconds);
        uint256 expectPercent3 = createPool.unlockPercent;
        uint256 actualPercent3 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent3, actualPercent3);

        vm.warp(times[0] - 1 seconds);
        uint256 expectPercent4 = createPool.unlockPercent;
        uint256 actualPercent4 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent4, actualPercent4);

        vm.warp(times[0]);
        uint256 expectPercent5 = createPool.unlockPercent + percents[0];
        uint256 actualPercent5 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent5, actualPercent5);

        vm.warp(times[1] - 1);
        uint256 expectPercent6 = createPool.unlockPercent + percents[0];
        uint256 actualPercent6 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent6, actualPercent6);

        vm.warp(times[1]);
        uint256 expectPercent7 = createPool.unlockPercent + percents[0] + percents[1];
        uint256 actualPercent7 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent7, actualPercent7);

        vm.warp(times[2] - 1);
        uint256 expectPercent8 = createPool.unlockPercent + percents[0] + percents[1];
        uint256 actualPercent8 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent8, actualPercent8);

        vm.warp(times[2]);
        uint256 expectPercent9 = 10_000;
        uint256 actualPercent9 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent9, actualPercent9);

        vm.warp(times[2] + 100 seconds);
        uint256 expectPercent10 = 10_000;
        uint256 actualPercent10 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent10, actualPercent10);
    }

    function test_GetCurrentClaimPercent_VESTING_TYPE_LINEAR_UNLOCK_FIRST_ShouldRight() public {
        uint256 poolId = 1;

        CreatePool memory createPool = _createPool(
            VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST, block.timestamp + 1 days, 60 days, 1000, 360 days, times, percents
        );
        // - vesting type , tge , cliff, unlockpercent , linearDuration, time , percent

        vm.startPrank(users.admin);
        purrVesting.createPool(createPool);

        uint256 totalAmount;

        for (uint256 i; i < amounts.length;) {
            totalAmount += amounts[i];

            unchecked {
                ++i;
            }
        }

        erc20IDO.approve(address(purrVesting), totalAmount);

        purrVesting.addFund(poolId, amounts, depositorAddresses);

        vm.stopPrank();

        vm.warp(createPool.tge - 1);
        uint256 expectPercent1 = 0;
        assertEq(expectPercent1, purrVesting.getCurrentClaimPercent(poolId));

        vm.warp(createPool.tge);
        uint256 expectPercent2 = createPool.unlockPercent;
        uint256 actualPercent2 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent2, actualPercent2);

        vm.warp(createPool.tge + createPool.cliff - 1 seconds);
        uint256 expectPercent3 = createPool.unlockPercent;
        uint256 actualPercent3 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent3, actualPercent3);

        vm.warp(createPool.tge + createPool.cliff + 199 days);
        uint256 expectPercent4 = (block.timestamp - createPool.tge - createPool.cliff).mulDiv(
            10_000 - createPool.unlockPercent, createPool.linearVestingDuration, Math.Rounding.Floor
        ) + createPool.unlockPercent;
        uint256 actualPercent4 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent4, actualPercent4);

        vm.warp(createPool.tge + createPool.cliff + 367 days);
        uint256 expectPercent5 = 10_000;
        uint256 actualPercent5 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent5, actualPercent5);
    }

    function test_GetCurrentClaimPercent_VESTING_TYPE_LINEAR_CLIFF_FIRST_ShouldRight() public {
        uint256 poolId = 1;

        CreatePool memory createPool = _createPool(
            VestingType.VESTING_TYPE_LINEAR_CLIFF_FIRST, block.timestamp + 1 days, 60 days, 1000, 360 days, times, percents
        );
        // - vesting type , tge , cliff, unlockpercent , linearDuration, time , percent

        vm.startPrank(users.admin);
        purrVesting.createPool(createPool);

        uint256 totalAmount;

        for (uint256 i; i < amounts.length;) {
            totalAmount += amounts[i];

            unchecked {
                ++i;
            }
        }

        erc20IDO.approve(address(purrVesting), totalAmount);

        purrVesting.addFund(poolId, amounts, depositorAddresses);

        vm.stopPrank();

        vm.warp(createPool.tge + createPool.cliff - 1 seconds);
        uint256 expectPercent1 = 0;
        assertEq(expectPercent1, purrVesting.getCurrentClaimPercent(poolId));

        vm.warp(createPool.tge + createPool.cliff);
        uint256 expectPercent2 = createPool.unlockPercent;
        uint256 actualPercent2 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent2, actualPercent2);

        vm.warp(createPool.tge + createPool.cliff + 210 days);
        uint256 expectPercent4 = (block.timestamp - createPool.tge - createPool.cliff).mulDiv(
            10_000 - createPool.unlockPercent, createPool.linearVestingDuration, Math.Rounding.Floor
        ) + createPool.unlockPercent;
        uint256 actualPercent4 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent4, actualPercent4);

        vm.warp(createPool.tge + createPool.cliff + 366 days);
        uint256 expectPercent5 = 10_000;
        uint256 actualPercent5 = purrVesting.getCurrentClaimPercent(poolId);
        assertEq(expectPercent5, actualPercent5);
    }

    function test_ClaimFund_ShouldRevert_WhenInvalidState() public {
        uint256 poolId = 1;

        uint256 linearDuration = 365 days;

        CreatePool memory createPool = _createPool(
            VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST, block.timestamp + 1 days, 60 days, 1000, linearDuration, times, percents
        );
        // - vesting type , tge , cliff, unlockpercent , linearDuration, time , percent

        vm.startPrank(users.admin);
        purrVesting.createPool(createPool);

        uint256 totalAmount;

        for (uint256 i; i < amounts.length;) {
            totalAmount += amounts[i];

            unchecked {
                ++i;
            }
        }

        erc20IDO.approve(address(purrVesting), totalAmount);

        purrVesting.addFund(poolId, amounts, depositorAddresses);

        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("InvalidState(uint8)"));
        vm.expectRevert(abi.encodeWithSelector(selector, PoolState.INIT));

        vm.startPrank(users.alice);
        purrVesting.claimFund(poolId);
        vm.stopPrank();
    }

    function test_ClaimFund_ShouldRevert_WhenInvalidClaimer() public {
        uint256 poolId = 1;

        uint256 linearDuration = 365 days;

        CreatePool memory createPool = _createPool(
            VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST, block.timestamp + 1 days, 60 days, 1000, linearDuration, times, percents
        );
        // - vesting type , tge , cliff, unlockpercent , linearDuration, time , percent

        vm.startPrank(users.admin);
        purrVesting.createPool(createPool);

        uint256 totalAmount;

        for (uint256 i; i < amounts.length;) {
            totalAmount += amounts[i];

            unchecked {
                ++i;
            }
        }

        erc20IDO.approve(address(purrVesting), totalAmount);

        purrVesting.start(poolId);
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("InvalidClaimer(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.startPrank(users.alice);
        purrVesting.claimFund(poolId);
        vm.stopPrank();
    }

    function test_ClaimFund_ShouldRevert_WhenInvalidTime() public {
        uint256 poolId = 1;

        uint256 linearDuration = 365 days;

        CreatePool memory createPool = _createPool(
            VestingType.VESTING_TYPE_LINEAR_CLIFF_FIRST, block.timestamp + 1 days, 60 days, 1000, linearDuration, times, percents
        );
        // - vesting type , tge , cliff, unlockpercent , linearDuration, time , percent

        vm.startPrank(users.admin);
        purrVesting.createPool(createPool);

        uint256 totalAmount;

        for (uint256 i; i < amounts.length;) {
            totalAmount += amounts[i];

            unchecked {
                ++i;
            }
        }

        erc20IDO.approve(address(purrVesting), totalAmount);

        purrVesting.addFund(poolId, amounts, depositorAddresses);
        purrVesting.start(poolId);

        vm.stopPrank();

        vm.startPrank(users.alice);
        vm.warp(createPool.tge - 1 seconds);

        bytes4 selector = bytes4(keccak256("InvalidTime(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, block.timestamp));

        purrVesting.claimFund(poolId);
        vm.stopPrank();
    }

    function test_ClaimFund_SHouldRevert_WhenInvalidClaimPercent() public {
        uint256 poolId = 1;

        uint256 linearDuration = 365 days;

        CreatePool memory createPool = _createPool(
            VestingType.VESTING_TYPE_LINEAR_CLIFF_FIRST, block.timestamp + 1 days, 60 days, 1000, linearDuration, times, percents
        );
        // - vesting type , tge , cliff, unlockpercent , linearDuration, time , percent

        vm.startPrank(users.admin);
        purrVesting.createPool(createPool);

        uint256 totalAmount;

        for (uint256 i; i < amounts.length;) {
            totalAmount += amounts[i];

            unchecked {
                ++i;
            }
        }

        erc20IDO.approve(address(purrVesting), totalAmount);

        purrVesting.addFund(poolId, amounts, depositorAddresses);
        purrVesting.start(poolId);

        vm.stopPrank();

        vm.startPrank(users.alice);
        vm.warp(createPool.tge + createPool.cliff - 1 seconds);

        bytes4 selector = bytes4(keccak256("InvalidClaimPercent()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        purrVesting.claimFund(poolId);
        vm.stopPrank();
    }

    function test_ClaimFund_ShouldClaimFunded() public {
        uint256 poolId = 1;

        uint256 linearDuration = 365 days;

        CreatePool memory createPool = _createPool(
            VestingType.VESTING_TYPE_LINEAR_CLIFF_FIRST, block.timestamp + 1 days, 60 days, 1000, linearDuration, times, percents
        );
        // - vesting type , tge , cliff, unlockpercent , linearDuration, time , percent

        vm.startPrank(users.admin);
        purrVesting.createPool(createPool);

        uint256 totalAmount;

        for (uint256 i; i < amounts.length;) {
            totalAmount += amounts[i];

            unchecked {
                ++i;
            }
        }

        erc20IDO.approve(address(purrVesting), totalAmount);

        purrVesting.addFund(poolId, amounts, depositorAddresses);
        purrVesting.start(poolId);

        vm.stopPrank();

        uint256 preUserReleased = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        uint256 prePoolFundClaimed = purrVesting.getPoolInfo(poolId).fundsClaimed;

        vm.startPrank(users.alice);
        vm.warp(createPool.tge + createPool.cliff);
        uint256 pendingReward = purrVesting.getPendingFund(poolId, users.alice);
        purrVesting.claimFund(poolId);
        vm.stopPrank();

        uint256 posUserReleased = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        uint256 posPoolFundClaimed = purrVesting.getPoolInfo(poolId).fundsClaimed;

        assertEq(preUserReleased + pendingReward, posUserReleased);
        assertEq(prePoolFundClaimed + pendingReward, posPoolFundClaimed);
        assertEq(pendingReward, erc20IDO.balanceOf(users.alice));
    }

    function test_ClaimFund_ShouldEmit_EventClaimFund() public {
        uint256 poolId = 1;

        uint256 linearDuration = 365 days;

        CreatePool memory createPool = _createPool(
            VestingType.VESTING_TYPE_LINEAR_CLIFF_FIRST, block.timestamp + 1 days, 60 days, 1000, linearDuration, times, percents
        );
        // - vesting type , tge , cliff, unlockpercent , linearDuration, time , percent

        vm.startPrank(users.admin);
        purrVesting.createPool(createPool);

        uint256 totalAmount;

        for (uint256 i; i < amounts.length;) {
            totalAmount += amounts[i];

            unchecked {
                ++i;
            }
        }

        erc20IDO.approve(address(purrVesting), totalAmount);

        purrVesting.addFund(poolId, amounts, depositorAddresses);
        purrVesting.start(poolId);

        vm.stopPrank();

        uint256 preUserReleased = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        uint256 prePoolFundClaimed = purrVesting.getPoolInfo(poolId).fundsClaimed;

        vm.warp(createPool.tge + createPool.cliff);
        uint256 pendingReward = purrVesting.getPendingFund(poolId, users.alice);

        vm.expectEmit(true, true, true, true);
        emit ClaimFundEvent(poolId, users.alice, pendingReward);

        vm.startPrank(users.alice);
        purrVesting.claimFund(poolId);
        vm.stopPrank();
    }

    function test_ClaimFund_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldClaimFunded() public {
        uint256 poolId = 1;

        times.push(uint64(block.timestamp + 100 days));
        times.push(uint64(block.timestamp + 200 days));
        times.push(uint64(block.timestamp + 300 days));

        percents.push(uint16(2000));
        percents.push(uint16(3000));
        percents.push(uint16(4000));

        CreatePool memory createPool = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST, block.timestamp + 1 days, 60 days, 1000, 0, times, percents
        );
        // - vesting type , tge , cliff, unlockpercent , linearDuration, time , percent

        vm.startPrank(users.admin);
        purrVesting.createPool(createPool);

        uint256 totalAmount;

        for (uint256 i; i < amounts.length;) {
            totalAmount += amounts[i];

            unchecked {
                ++i;
            }
        }

        erc20IDO.approve(address(purrVesting), totalAmount);

        purrVesting.addFund(poolId, amounts, depositorAddresses);
        purrVesting.start(poolId);

        vm.stopPrank();

        vm.warp(createPool.tge + createPool.cliff - 1 seconds);

        uint256 preFundClaimed = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased = purrVesting.getUserClaimInfo(poolId, users.alice).released;

        vm.startPrank(users.alice);
        bytes4 selector1 = bytes4(keccak256("InvalidClaimPercent()"));
        vm.expectRevert(abi.encodeWithSelector(selector1));
        uint256 fundPending = purrVesting.getPendingFund(poolId, users.alice);

        bytes4 selector2 = bytes4(keccak256("InvalidClaimPercent()"));
        vm.expectRevert(abi.encodeWithSelector(selector2));
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        vm.stopPrank();

        assertEq(posFundClaimed, 0);
        assertEq(posUserReleased, 0);
        assertEq(posFundClaimed, preFundClaimed + fundPending);
        assertEq(posUserReleased, preUserReleased + fundPending);
        assertEq(erc20IDO.balanceOf(users.alice), 0);

        vm.warp(createPool.tge + createPool.cliff);
        uint256 preFundClaimed1 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased1 = purrVesting.getUserClaimInfo(poolId, users.alice).released;

        vm.startPrank(users.alice);
        uint256 fundPending1 = purrVesting.getPendingFund(poolId, users.alice);
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed1 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased1 = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        vm.stopPrank();

        assertEq(posFundClaimed1, preFundClaimed1 + fundPending1);
        assertEq(posUserReleased1, preUserReleased1 + fundPending1);
        assertGt(erc20IDO.balanceOf(users.alice), 0);

        vm.warp(times[1] + 1 days);
        uint256 preFundClaimed2 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased2 = purrVesting.getUserClaimInfo(poolId, users.alice).released;

        vm.startPrank(users.alice);
        uint256 fundPending2 = purrVesting.getPendingFund(poolId, users.alice);
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed2 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased2 = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        vm.stopPrank();

        assertEq(posFundClaimed2, preFundClaimed2 + fundPending2);
        assertEq(posUserReleased2, preUserReleased2 + fundPending2);
        assertGt(erc20IDO.balanceOf(users.alice), 0);
        assertLt(erc20IDO.balanceOf(users.alice), amounts[0]);

        vm.warp(times[2] + 1 days);
        uint256 preFundClaimed3 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased3 = purrVesting.getUserClaimInfo(poolId, users.alice).released;

        vm.startPrank(users.alice);
        uint256 fundPending3 = purrVesting.getPendingFund(poolId, users.alice);
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed3 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased3 = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        vm.stopPrank();

        assertEq(posFundClaimed3, preFundClaimed3 + fundPending3);
        assertEq(posUserReleased3, preUserReleased3 + fundPending3);
        assertEq(posFundClaimed3, amounts[0]);
        assertEq(posUserReleased3, amounts[0]);
        assertGt(erc20IDO.balanceOf(users.alice), 0);
    }

    function test_ClaimFund_VESTING_TYPE_MILESTONE_UNLOCK_FIRST_ShouldClaimFunded() public {
        uint256 poolId = 1;

        times.push(uint64(block.timestamp + 100 days));
        times.push(uint64(block.timestamp + 200 days));
        times.push(uint64(block.timestamp + 300 days));

        percents.push(uint16(2000));
        percents.push(uint16(3000));
        percents.push(uint16(4000));

        CreatePool memory createPool = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST, block.timestamp + 1 days, 60 days, 1000, 0, times, percents
        );
        // - vesting type , tge , cliff, unlockpercent , linearDuration, time , percent

        vm.startPrank(users.admin);
        purrVesting.createPool(createPool);

        uint256 totalAmount;

        for (uint256 i; i < amounts.length;) {
            totalAmount += amounts[i];

            unchecked {
                ++i;
            }
        }

        erc20IDO.approve(address(purrVesting), totalAmount);

        purrVesting.addFund(poolId, amounts, depositorAddresses);
        purrVesting.start(poolId);

        vm.stopPrank();

        vm.warp(createPool.tge - 1 seconds);
        uint256 preFundClaimed = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased = purrVesting.getUserClaimInfo(poolId, users.alice).released;

        vm.startPrank(users.alice);
        bytes4 selector1 = bytes4(keccak256("InvalidTime(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector1, block.timestamp));
        uint256 fundPending = purrVesting.getPendingFund(poolId, users.alice);

        bytes4 selector2 = bytes4(keccak256("InvalidTime(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector2, block.timestamp));
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        vm.stopPrank();

        assertEq(posFundClaimed, 0);
        assertEq(posUserReleased, 0);
        assertEq(posFundClaimed, preFundClaimed + fundPending);
        assertEq(posUserReleased, preUserReleased + fundPending);
        assertEq(erc20IDO.balanceOf(users.alice), 0);

        vm.warp(createPool.tge);
        uint256 preFundClaimed1 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased1 = purrVesting.getUserClaimInfo(poolId, users.alice).released;

        vm.startPrank(users.alice);
        uint256 fundPending1 = purrVesting.getPendingFund(poolId, users.alice);
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed1 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased1 = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        vm.stopPrank();

        assertEq(posFundClaimed1, preFundClaimed1 + fundPending1);
        assertEq(posUserReleased1, preUserReleased1 + fundPending1);
        assertGt(erc20IDO.balanceOf(users.alice), 0);

        vm.warp(times[1] + 1 days);
        uint256 preFundClaimed2 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased2 = purrVesting.getUserClaimInfo(poolId, users.alice).released;

        vm.startPrank(users.alice);
        uint256 fundPending2 = purrVesting.getPendingFund(poolId, users.alice);
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed2 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased2 = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        vm.stopPrank();

        assertEq(posFundClaimed2, preFundClaimed2 + fundPending2);
        assertEq(posUserReleased2, preUserReleased2 + fundPending2);
        assertGt(erc20IDO.balanceOf(users.alice), 0);
        assertLt(erc20IDO.balanceOf(users.alice), amounts[0]);

        vm.warp(times[2] + 1 days);
        uint256 preFundClaimed3 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased3 = purrVesting.getUserClaimInfo(poolId, users.alice).released;

        vm.startPrank(users.alice);
        uint256 fundPending3 = purrVesting.getPendingFund(poolId, users.alice);
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed3 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased3 = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        vm.stopPrank();

        assertEq(posFundClaimed3, preFundClaimed3 + fundPending3);
        assertEq(posUserReleased3, preUserReleased3 + fundPending3);
        assertEq(posFundClaimed3, amounts[0]);
        assertEq(posUserReleased3, amounts[0]);
        assertGt(erc20IDO.balanceOf(users.alice), 0);
    }

    function test_ClaimFund_VESTING_TYPE_LINEAR_UNLOCK_FIRST_ShouldClaimFunded() public {
        uint256 poolId = 1;

        uint256 linearDuration = 365 days;

        CreatePool memory createPool = _createPool(
            VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST, block.timestamp + 1 days, 60 days, 1000, linearDuration, times, percents
        );
        // - vesting type , tge , cliff, unlockpercent , linearDuration, time , percent

        vm.startPrank(users.admin);
        purrVesting.createPool(createPool);

        uint256 totalAmount;

        for (uint256 i; i < amounts.length;) {
            totalAmount += amounts[i];

            unchecked {
                ++i;
            }
        }

        erc20IDO.approve(address(purrVesting), totalAmount);

        purrVesting.addFund(poolId, amounts, depositorAddresses);
        purrVesting.start(poolId);

        vm.stopPrank();

        vm.warp(createPool.tge - 1 seconds);
        uint256 preFundClaimed = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased = purrVesting.getUserClaimInfo(poolId, users.alice).released;

        vm.startPrank(users.alice);
        bytes4 selector1 = bytes4(keccak256("InvalidTime(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector1, block.timestamp));
        uint256 fundPending = purrVesting.getPendingFund(poolId, users.alice);

        bytes4 selector2 = bytes4(keccak256("InvalidTime(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector2, block.timestamp));
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        vm.stopPrank();

        assertEq(posFundClaimed, 0);
        assertEq(posUserReleased, 0);
        assertEq(posFundClaimed, preFundClaimed + fundPending);
        assertEq(posUserReleased, preUserReleased + fundPending);
        assertEq(erc20IDO.balanceOf(users.alice), 0);

        vm.warp(createPool.tge);
        uint256 preFundClaimed1 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased1 = purrVesting.getUserClaimInfo(poolId, users.alice).released;

        vm.startPrank(users.alice);
        uint256 fundPending1 = purrVesting.getPendingFund(poolId, users.alice);
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed1 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased1 = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        vm.stopPrank();

        assertEq(posFundClaimed1, preFundClaimed1 + fundPending1);
        assertEq(posUserReleased1, preUserReleased1 + fundPending1);
        assertGt(erc20IDO.balanceOf(users.alice), 0);

        vm.warp(createPool.tge + createPool.cliff + createPool.linearVestingDuration - 100 days);
        uint256 preFundClaimed2 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased2 = purrVesting.getUserClaimInfo(poolId, users.alice).released;

        vm.startPrank(users.alice);
        uint256 fundPending2 = purrVesting.getPendingFund(poolId, users.alice);
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed2 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased2 = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        vm.stopPrank();

        assertEq(posFundClaimed2, preFundClaimed2 + fundPending2);
        assertEq(posUserReleased2, preUserReleased2 + fundPending2);
        assertGt(erc20IDO.balanceOf(users.alice), 0);
        assertLt(erc20IDO.balanceOf(users.alice), amounts[0]);

        vm.warp(createPool.tge + createPool.cliff + createPool.linearVestingDuration + 1 days);
        uint256 preFundClaimed3 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased3 = purrVesting.getUserClaimInfo(poolId, users.alice).released;

        vm.startPrank(users.alice);
        uint256 fundPending3 = purrVesting.getPendingFund(poolId, users.alice);
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed3 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased3 = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        vm.stopPrank();

        assertEq(posFundClaimed3, preFundClaimed3 + fundPending3);
        assertEq(posUserReleased3, preUserReleased3 + fundPending3);
        assertEq(posFundClaimed3, amounts[0]);
        assertEq(posUserReleased3, amounts[0]);
        assertGt(erc20IDO.balanceOf(users.alice), 0);
    }

    function test_ClaimFund_VESTING_TYPE_LINEAR_CLIFF_FIRST_ShouldClaimFunded() public {
        uint256 poolId = 1;

        uint256 linearDuration = 365 days;

        CreatePool memory createPool = _createPool(
            VestingType.VESTING_TYPE_LINEAR_CLIFF_FIRST, block.timestamp + 1 days, 60 days, 1000, linearDuration, times, percents
        );
        // - vesting type , tge , cliff, unlockpercent , linearDuration, time , percent

        vm.startPrank(users.admin);
        purrVesting.createPool(createPool);

        uint256 totalAmount;

        for (uint256 i; i < amounts.length;) {
            totalAmount += amounts[i];

            unchecked {
                ++i;
            }
        }

        erc20IDO.approve(address(purrVesting), totalAmount);

        purrVesting.addFund(poolId, amounts, depositorAddresses);
        purrVesting.start(poolId);

        vm.stopPrank();
        vm.warp(createPool.tge + createPool.cliff - 1 seconds);
        uint256 preFundClaimed = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased = purrVesting.getUserClaimInfo(poolId, users.alice).released;

        vm.startPrank(users.alice);
        bytes4 selector1 = bytes4(keccak256("InvalidClaimPercent()"));
        vm.expectRevert(abi.encodeWithSelector(selector1));
        uint256 fundPending = purrVesting.getPendingFund(poolId, users.alice);

        bytes4 selector2 = bytes4(keccak256("InvalidClaimPercent()"));
        vm.expectRevert(abi.encodeWithSelector(selector2));
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        vm.stopPrank();

        assertEq(posFundClaimed, 0);
        assertEq(posUserReleased, 0);
        assertEq(posFundClaimed, preFundClaimed + fundPending);
        assertEq(posUserReleased, preUserReleased + fundPending);
        assertEq(erc20IDO.balanceOf(users.alice), 0);

        vm.warp(createPool.tge + createPool.cliff);
        uint256 preFundClaimed1 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased1 = purrVesting.getUserClaimInfo(poolId, users.alice).released;

        vm.startPrank(users.alice);
        uint256 fundPending1 = purrVesting.getPendingFund(poolId, users.alice);
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed1 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased1 = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        vm.stopPrank();

        assertEq(posFundClaimed1, preFundClaimed1 + fundPending1);
        assertEq(posUserReleased1, preUserReleased1 + fundPending1);
        assertGt(erc20IDO.balanceOf(users.alice), 0);

        vm.warp(createPool.tge + createPool.cliff + createPool.linearVestingDuration - 100 days);
        uint256 preFundClaimed2 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased2 = purrVesting.getUserClaimInfo(poolId, users.alice).released;

        vm.startPrank(users.alice);
        uint256 fundPending2 = purrVesting.getPendingFund(poolId, users.alice);
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed2 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased2 = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        vm.stopPrank();

        assertEq(posFundClaimed2, preFundClaimed2 + fundPending2);
        assertEq(posUserReleased2, preUserReleased2 + fundPending2);
        assertGt(erc20IDO.balanceOf(users.alice), 0);
        assertLt(erc20IDO.balanceOf(users.alice), amounts[0]);

        vm.warp(createPool.tge + createPool.cliff + createPool.linearVestingDuration + 1 days);
        uint256 preFundClaimed3 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased3 = purrVesting.getUserClaimInfo(poolId, users.alice).released;

        vm.startPrank(users.alice);
        uint256 fundPending3 = purrVesting.getPendingFund(poolId, users.alice);
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed3 = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased3 = purrVesting.getUserClaimInfo(poolId, users.alice).released;
        vm.stopPrank();

        assertEq(posFundClaimed3, preFundClaimed3 + fundPending3);
        assertEq(posUserReleased3, preUserReleased3 + fundPending3);
        assertEq(posFundClaimed3, amounts[0]);
        assertEq(posUserReleased3, amounts[0]);
        assertGt(erc20IDO.balanceOf(users.alice), 0);
    }

    /// NGUYEN
    function test_CreatePool_ShouldRevert_WhenNotOwner() public {
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];

        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST,
            uint256(block.timestamp + 1 days),
            uint256(120 days),
            uint256(2555),
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_ShouldRevert_WhenInvalid_TGE_LessThanTimestamp() public {
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST,
            uint256(block.timestamp + 1 days),
            uint256(120 days),
            uint256(2555),
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        vm.warp(2 days);
        bytes4 selector = bytes4(keccak256("InvalidArgPercentCreatePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_ShouldRevert_WhenInvalid_GreaterThanOneHundredPervent() public {
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];

        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST,
            uint256(block.timestamp + 1 days),
            uint256(120 days),
            uint256(10_001),
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        bytes4 selector = bytes4(keccak256("InvalidArgPercentCreatePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldRevert_WhenInvalid_DifferenceLengthTimesAndPercents()
        public
    {
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];

        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST,
            uint256(block.timestamp + 1 days),
            uint256(120 days),
            uint256(30),
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        bytes4 selector = bytes4(keccak256("InvalidArgCreatePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_VESTING_TYPE_MILESTONE_UNLOCK_FIRST_ShouldRevert_WhenInvalid_DifferenceLengthTimesAndPercents()
        public
    {
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];

        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST,
            uint256(block.timestamp + 1 days),
            uint256(120 days),
            uint256(30),
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        bytes4 selector = bytes4(keccak256("InvalidArgCreatePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldRevert_WhenInvalid_LinierVestingDurationDifferenceZero()
        public
    {
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];

        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST,
            uint256(block.timestamp + 1 days),
            uint256(120 days),
            uint256(30),
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        bytes4 selector = bytes4(keccak256("InvalidArgCreatePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_VESTING_TYPE_MILESTONE_UNLOCK_FIRST_ShouldRevert_WhenInvalid_LinierVestingDurationDifferenceZero()
        public
    {
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST,
            uint256(block.timestamp + 1 days),
            uint256(120 days),
            uint256(30),
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        bytes4 selector = bytes4(keccak256("InvalidArgCreatePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldRevert_WhenInvalid_Time_LessThanSumTgeAndCliffTime()
        public
    {
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 1 days, 2 days, 3 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST,
            uint256(block.timestamp + 1 days),
            uint256(120 days),
            uint256(30),
            0,
            times,
            percents
        );

        bytes4 selector = bytes4(keccak256("InvalidArgMileStoneCreatePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_VESTING_TYPE_MILESTONE_UNLOCK_FIRST_ShouldRevert_WhenInvalid_Time_LessThanSumTgeAndCliffTime()
        public
    {
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 1 days, 2 days, 3 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];

        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST,
            uint256(block.timestamp + 1 days),
            uint256(120 days),
            uint256(30),
            0,
            times,
            percents
        );

        bytes4 selector = bytes4(keccak256("InvalidArgMileStoneCreatePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldRevert_WhenInvalid_Time_tmpTimeLessThanCurTime() public {
        times = [10 days, 20 days, 30 days, 4 days, 5 days, 6 days, 7 days, 8 days, 9 days, 10 days];
        percents = [10, 10, 10, 10, 10, 10, 10, 10, 10, 10];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST,
            uint256(block.timestamp + 1 days),
            1 days,
            uint256(30),
            0,
            times,
            percents
        );

        bytes4 selector = bytes4(keccak256("InvalidArgMileStoneCreatePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_VESTING_TYPE_MILESTONE_UNLOCK_FIRST_ShouldRevert_WhenInvalid_Time_tmpTimeLessThanCurTime() public {
        times = [10 days, 20 days, 30 days, 4 days, 5 days, 6 days, 7 days, 8 days, 9 days, 10 days];
        percents = [10, 10, 10, 10, 10, 10, 10, 10, 10, 10];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST,
            uint256(block.timestamp + 1 days),
            1 days,
            uint256(30),
            0,
            times,
            percents
        );

        bytes4 selector = bytes4(keccak256("InvalidArgMileStoneCreatePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_VESTING_TYPE_LINEAR_UNLOCK_FIRST_ShouldRevert_WhenInvalid_TimesLengthDifferenceZero() public {
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];

        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST,
            uint256(block.timestamp + 1 days),
            1 days,
            uint256(30),
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        bytes4 selector = bytes4(keccak256("InvalidArgLinearCreatePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_VESTING_TYPE_LINEAR_CLIFF_FIRST_ShouldRevert_WhenInvalid_TimesLengthDifferenceZero() public {
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];

        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_LINEAR_CLIFF_FIRST,
            uint256(block.timestamp + 1 days),
            1 days,
            uint256(30),
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        bytes4 selector = bytes4(keccak256("InvalidArgLinearCreatePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_VESTING_TYPE_LINEAR_UNLOCK_FIRST_ShouldRevert_WhenInvalid_PercentsLengthDifferenceZero() public {
        percents = [10, 10, 10, 10, 10, 10, 10, 10, 10, 10];

        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_LINEAR_CLIFF_FIRST,
            uint256(block.timestamp + 1 days),
            1 days,
            uint256(30),
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        bytes4 selector = bytes4(keccak256("InvalidArgLinearCreatePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_VESTING_TYPE_LINEAR_CLIFF_FIRST_ShouldRevert_WhenInvalid_PercentsLengthDifferenceZero() public {
        percents = [10, 10, 10, 10, 10, 10, 10, 10, 10, 10];

        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_LINEAR_CLIFF_FIRST,
            uint256(block.timestamp + 1 days),
            1 days,
            uint256(30),
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        bytes4 selector = bytes4(keccak256("InvalidArgLinearCreatePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_VESTING_TYPE_LINEAR_UNLOCK_FIRST_ShouldRevert_WhenInvalid_VestingDurationEqualOrLessThanZero()
        public
    {
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST,
            uint256(block.timestamp + 1 days),
            1 days,
            uint256(30),
            0,
            times,
            percents
        );

        bytes4 selector = bytes4(keccak256("InvalidArgLinearCreatePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_VESTING_TYPE_LINEAR_CLIFF_FIRST_ShouldRevert_WhenInvalid_VestingDurationEqualOrLessThanZero()
        public
    {
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_LINEAR_CLIFF_FIRST,
            uint256(block.timestamp + 1 days),
            1 days,
            uint256(30),
            0,
            times,
            percents
        );

        bytes4 selector = bytes4(keccak256("InvalidArgLinearCreatePool()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldCreatePooled() public {
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST, uint256(block.timestamp + 1 days), 1 days, 1000, 0, times, percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        assertEq(purrVesting.poolIndex(), 1);

        Pool memory _pool = Pool({
            id: 1,
            projectId: "17aa0f02-6ce1-4352-84ab-42bc0fa66d15",
            tokenFund: poolVesting.tokenFund,
            name: poolVesting.name,
            vestingType: poolVesting.vestingType,
            tge: poolVesting.tge,
            cliff: poolVesting.cliff,
            unlockPercent: poolVesting.unlockPercent,
            linearVestingDuration: poolVesting.linearVestingDuration,
            times: poolVesting.times,
            percents: poolVesting.percents,
            fundsTotal: 0,
            fundsClaimed: 0,
            state: PoolState.INIT
        });

        (
            uint256 _id,
            ,
            uint256 _tge,
            uint256 _cliff,
            uint256 _unlockPercent,
            uint256 _linearVestingDuration,
            uint256 _fundsTotal,
            uint256 _fundsClaimed,
            address _tokenFund,
            string memory _name,
            VestingType _vestingType,
            PoolState _state
        ) = purrVesting.poolInfo(1);

        Pool memory retrievedPool = Pool({
            id: _id,
            projectId: "17aa0f02-6ce1-4352-84ab-42bc0fa66d15",
            tokenFund: _tokenFund,
            name: _name,
            vestingType: _vestingType,
            tge: _tge,
            cliff: _cliff,
            unlockPercent: _unlockPercent,
            linearVestingDuration: _linearVestingDuration,
            times: times,
            percents: percents,
            fundsTotal: _fundsTotal,
            fundsClaimed: _fundsClaimed,
            state: _state
        });

        assertEq(abi.encode(_pool), abi.encode(retrievedPool));
    }

    function test_CreatePool_VESTING_TYPE_MILESTONE_UNLOCK_FIRST_ShouldCreatePool() public {
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST, uint256(block.timestamp + 1 days), 1 days, 1000, 0, times, percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 1;
        assertEq(purrVesting.poolIndex(), poolIndex);

        Pool memory _pool = Pool({
            id: poolIndex,
            projectId: "17aa0f02-6ce1-4352-84ab-42bc0fa66d15",
            tokenFund: poolVesting.tokenFund,
            name: poolVesting.name,
            vestingType: poolVesting.vestingType,
            tge: poolVesting.tge,
            cliff: poolVesting.cliff,
            unlockPercent: poolVesting.unlockPercent,
            linearVestingDuration: poolVesting.linearVestingDuration,
            times: poolVesting.times,
            percents: poolVesting.percents,
            fundsTotal: 0,
            fundsClaimed: 0,
            state: PoolState.INIT
        });

        (
            uint256 _id,
            ,
            uint256 _tge,
            uint256 _cliff,
            uint256 _unlockPercent,
            uint256 _linearVestingDuration,
            uint256 _fundsTotal,
            uint256 _fundsClaimed,
            address _tokenFund,
            string memory _name,
            VestingType _vestingType,
            PoolState _state
        ) = purrVesting.poolInfo(1);

        Pool memory retrievedPool = Pool({
            id: _id,
            projectId: "17aa0f02-6ce1-4352-84ab-42bc0fa66d15",
            tokenFund: _tokenFund,
            name: _name,
            vestingType: _vestingType,
            tge: _tge,
            cliff: _cliff,
            unlockPercent: _unlockPercent,
            linearVestingDuration: _linearVestingDuration,
            times: times,
            percents: percents,
            fundsTotal: _fundsTotal,
            fundsClaimed: _fundsClaimed,
            state: _state
        });

        assertEq(abi.encode(_pool), abi.encode(retrievedPool));
    }

    function test_CreatePool_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldEmit_CreatePoolEvent() public {
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST, uint256(block.timestamp + 1 days), 1 days, 1000, 0, times, percents
        );

        (
            uint256 _id,
            ,
            uint256 _tge,
            uint256 _cliff,
            uint256 _unlockPercent,
            uint256 _linearVestingDuration,
            uint256 _fundsTotal,
            uint256 _fundsClaimed,
            address _tokenFund,
            string memory _name,
            VestingType _vestingType,
            PoolState _state
        ) = purrVesting.poolInfo(1);

        Pool memory retrievedPool = Pool({
            id: _id,
            projectId: "17aa0f02-6ce1-4352-84ab-42bc0fa66d15",
            tokenFund: _tokenFund,
            name: _name,
            vestingType: _vestingType,
            tge: _tge,
            cliff: _cliff,
            unlockPercent: _unlockPercent,
            linearVestingDuration: _linearVestingDuration,
            times: times,
            percents: percents,
            fundsTotal: _fundsTotal,
            fundsClaimed: _fundsClaimed,
            state: _state
        });

        vm.expectEmit(true, true, false, false);
        emit CreatePoolEvent(retrievedPool);

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_CreatePool_VESTING_TYPE_LINEAR_UNLOCK_FIRST_ShouldEmit_CreatePoolEvent() public {
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST,
            uint256(block.timestamp + 1 days),
            1 days,
            1000,
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        (
            uint256 _id,
            ,
            uint256 _tge,
            uint256 _cliff,
            uint256 _unlockPercent,
            uint256 _linearVestingDuration,
            uint256 _fundsTotal,
            uint256 _fundsClaimed,
            address _tokenFund,
            string memory _name,
            VestingType _vestingType,
            PoolState _state
        ) = purrVesting.poolInfo(1);

        Pool memory retrievedPool = Pool({
            id: _id,
            projectId: "17aa0f02-6ce1-4352-84ab-42bc0fa66d15",
            tokenFund: _tokenFund,
            name: _name,
            vestingType: _vestingType,
            tge: _tge,
            cliff: _cliff,
            unlockPercent: _unlockPercent,
            linearVestingDuration: _linearVestingDuration,
            times: times,
            percents: percents,
            fundsTotal: _fundsTotal,
            fundsClaimed: _fundsClaimed,
            state: _state
        });

        vm.expectEmit(true, true, false, false);
        emit CreatePoolEvent(retrievedPool);

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);
    }

    function test_AddFund_ShouldRevert_WhenInvalidOwner() public {
        _users = [users.alice, users.bob];
        _fundAmounts = [1e18, 2e18];
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST, uint256(block.timestamp + 1 days), 1 days, 1000, 0, times, percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 1;

        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrVesting.addFund(poolIndex, _fundAmounts, _users);
    }

    function test_AddFund_ShouldRevert_WhenInvalidArgument() public {
        _users = [users.alice, users.bob];
        _fundAmounts = [1e18];
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST, uint256(block.timestamp + 1 days), 1 days, 1000, 0, times, percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 1;

        bytes4 selector = bytes4(keccak256("InvalidArgument()"));
        vm.expectRevert(abi.encodeWithSelector(selector));

        vm.prank(users.admin);
        purrVesting.addFund(poolIndex, _fundAmounts, _users);
    }

    function test_AddFund_ShouldRevert_WhenInvalidPoolIndexParam_GreaterThanPoolIndex() public {
        _users = [users.alice, users.bob];
        _fundAmounts = [1e18, 2e18];
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST, uint256(block.timestamp + 1 days), 1 days, 1000, 0, times, percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 2;

        bytes4 selector = bytes4(keccak256("InvalidPoolIndex(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 2));

        vm.prank(users.admin);
        purrVesting.addFund(poolIndex, _fundAmounts, _users);
    }

    function test_AddFund_ShouldRevert_WhenInvalidPoolIndexParam_LessThanOrEqualZero() public {
        _users = [users.alice, users.bob];
        _fundAmounts = [1e18, 2e18];
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST, uint256(block.timestamp + 1 days), 1 days, 1000, 0, times, percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 0;

        bytes4 selector = bytes4(keccak256("InvalidPoolIndex(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 0));

        vm.prank(users.admin);
        purrVesting.addFund(poolIndex, _fundAmounts, _users);
    }

    function test_AddFund_VESTING_TYPE_MILESTONE_UNLOCK_FIRST_ShouldAddFund() public {
        _users = [users.alice, users.bob];
        _fundAmounts = [1e18, 2e18];
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST, uint256(block.timestamp + 1 days), 1 days, 1000, 0, times, percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 1;
        uint256 length = _users.length;
        uint256 preTotalFundDeposit;
        uint256 posTotalFundDeposit;
        uint256 totalFundAmount;

        Pool memory _pool = purrVesting.getPoolInfo(poolIndex);

        for (uint256 i; i < length;) {
            vm.prank(_users[i]);
            UserPool memory _userPool = purrVesting.getUserClaimInfo(poolIndex, _users[i]);

            preTotalFundDeposit += _userPool.fund;
            totalFundAmount += _fundAmounts[i];

            unchecked {
                ++i;
            }
        }
        Pool memory _pool1 = purrVesting.getPoolInfo(poolIndex);
        uint256 prePoolFundsTotal = _pool1.fundsTotal;
        uint256 prePurrVestingBalance = ERC20Mock(_pool.tokenFund).balanceOf(address(purrVesting));
        uint256 preOwnerBalance = ERC20Mock(_pool.tokenFund).balanceOf(users.admin);

        vm.startPrank(users.admin);
        ERC20Mock(_pool.tokenFund).approve(address(purrVesting), 1000e18);
        purrVesting.addFund(poolIndex, _fundAmounts, _users);
        vm.stopPrank();

        for (uint256 i; i < length;) {
            vm.prank(_users[i]);
            UserPool memory _userPool = purrVesting.getUserClaimInfo(poolIndex, _users[i]);

            posTotalFundDeposit += _userPool.fund;

            unchecked {
                ++i;
            }
        }

        Pool memory _pool2 = purrVesting.getPoolInfo(poolIndex);
        uint256 posPoolFundsTotal = _pool2.fundsTotal;
        uint256 posPurrVestingBalance = ERC20Mock(_pool.tokenFund).balanceOf(address(purrVesting));
        uint256 posOwnerBalance = ERC20Mock(_pool.tokenFund).balanceOf(users.admin);

        uint256 retrievedTotalFund = posTotalFundDeposit - preTotalFundDeposit;
        uint256 retrievedPoolFundsTotal = posPoolFundsTotal - prePoolFundsTotal;
        uint256 retrievedTotalUsersFund = preOwnerBalance - posOwnerBalance;
        uint256 retrievedTotalPurrVestingFund = posPurrVestingBalance - prePurrVestingBalance;

        assertEq(retrievedTotalFund, totalFundAmount);
        assertEq(retrievedPoolFundsTotal, totalFundAmount);
        assertEq(retrievedTotalUsersFund, totalFundAmount);
        assertEq(retrievedTotalPurrVestingFund, totalFundAmount);
    }

    function test_AddFund_VESTING_TYPE_LINEAR_UNLOCK_FIRST_ShouldAddFund() public {
        _users = [users.alice, users.bob];
        _fundAmounts = [1e18, 2e18];

        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST,
            uint256(block.timestamp + 1 days),
            1 days,
            1000,
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 1;
        uint256 length = _users.length;
        uint256 preTotalFundDeposit;
        uint256 posTotalFundDeposit;
        uint256 totalFundAmount;
        uint256 prePoolFundsTotal;
        uint256 posPoolFundsTotal;
        uint256 preOwnerBalance;
        uint256 posOwnerBalance;
        uint256 prePurrVestingBalance;
        uint256 posPurrVestingBalance;

        Pool memory _pool = purrVesting.getPoolInfo(poolIndex);

        for (uint256 i; i < length;) {
            vm.prank(_users[i]);
            UserPool memory _userPool = purrVesting.getUserClaimInfo(poolIndex, _users[i]);

            preTotalFundDeposit += _userPool.fund;
            totalFundAmount += _fundAmounts[i];

            unchecked {
                ++i;
            }
        }
        Pool memory _pool1 = purrVesting.getPoolInfo(poolIndex);
        prePoolFundsTotal = _pool1.fundsTotal;
        prePurrVestingBalance = ERC20Mock(_pool.tokenFund).balanceOf(address(purrVesting));
        preOwnerBalance = ERC20Mock(_pool.tokenFund).balanceOf(users.admin);

        vm.startPrank(users.admin);
        ERC20Mock(_pool.tokenFund).approve(address(purrVesting), 1000e18);
        purrVesting.addFund(poolIndex, _fundAmounts, _users);
        vm.stopPrank();

        for (uint256 i; i < length;) {
            vm.prank(_users[i]);
            UserPool memory _userPool = purrVesting.getUserClaimInfo(poolIndex, _users[i]);

            posTotalFundDeposit += _userPool.fund;

            unchecked {
                ++i;
            }
        }
        Pool memory _pool2 = purrVesting.getPoolInfo(poolIndex);
        posPoolFundsTotal = _pool2.fundsTotal;
        posPurrVestingBalance = ERC20Mock(_pool.tokenFund).balanceOf(address(purrVesting));
        posOwnerBalance = ERC20Mock(_pool.tokenFund).balanceOf(users.admin);

        uint256 retrievedTotalFund = posTotalFundDeposit - preTotalFundDeposit;
        uint256 retrievedPoolFundsTatol = posPoolFundsTotal - prePoolFundsTotal;
        uint256 retrievedTotalUsersFund = preOwnerBalance - posOwnerBalance;
        uint256 retrievedTotalPurrVestingFund = posPurrVestingBalance - prePurrVestingBalance;

        assertEq(retrievedTotalFund, totalFundAmount);
        assertEq(retrievedPoolFundsTatol, totalFundAmount);
        assertEq(retrievedTotalUsersFund, totalFundAmount);
        assertEq(retrievedTotalPurrVestingFund, totalFundAmount);
    }

    function test_AddFund_VESTING_TYPE_MILESTONE_UNLOCK_FIRST_ShouldEmit_AddFundEvent() public {
        _users = [users.alice, users.bob];
        _fundAmounts = [1e18, 2e18];
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST, uint256(block.timestamp + 1 days), 1 days, 1000, 0, times, percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 1;
        Pool memory _pool = purrVesting.getPoolInfo(poolIndex);

        vm.startPrank(users.admin);
        ERC20Mock(_pool.tokenFund).approve(address(purrVesting), 1000e18);

        vm.expectEmit(true, true, true, true);
        emit AddFundEvent(poolIndex, _users, _fundAmounts);

        purrVesting.addFund(poolIndex, _fundAmounts, _users);
        vm.stopPrank();
    }

    function test_AddFund_VESTING_TYPE_LINEAR_UNLOCK_FIRST_ShouldEmit_AddFundEvent() public {
        _users = [users.alice, users.bob];
        _fundAmounts = [1e18, 2e18];

        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST,
            uint256(block.timestamp + 1 days),
            1 days,
            1000,
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 1;
        Pool memory _pool = purrVesting.getPoolInfo(poolIndex);

        vm.startPrank(users.admin);
        ERC20Mock(_pool.tokenFund).approve(address(purrVesting), 1000e18);

        vm.expectEmit(true, true, true, true);
        emit AddFundEvent(poolIndex, _users, _fundAmounts);

        purrVesting.addFund(poolIndex, _fundAmounts, _users);
        vm.stopPrank();
    }

    function test_RemoveFund_ShouldRevert_WhenInvalidOwner() public {
        _users = [users.alice, users.bob];
        _fundAmounts = [1e18, 2e18];
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST, uint256(block.timestamp + 1 days), 1 days, 1000, 0, times, percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 1;
        Pool memory _pool = purrVesting.getPoolInfo(poolIndex);

        vm.startPrank(users.admin);
        ERC20Mock(_pool.tokenFund).approve(address(purrVesting), 1000e18);
        purrVesting.addFund(poolIndex, _fundAmounts, _users);
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        vm.prank(users.alice);
        purrVesting.removeFund(poolIndex, _users);
    }

    function test_RemoveFund_VESTING_TYPE_MILESTONE_UNLOCK_FIRST_ShouldRevert_WhenInvalidPoolIndex_GreaterThanPoolIndex()
        public
    {
        _users = [users.alice, users.bob];
        _fundAmounts = [1e18, 2e18];
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST, uint256(block.timestamp + 1 days), 1 days, 1000, 0, times, percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 1;
        Pool memory _pool = purrVesting.getPoolInfo(poolIndex);

        vm.startPrank(users.admin);
        ERC20Mock(_pool.tokenFund).approve(address(purrVesting), 1000e18);
        purrVesting.addFund(poolIndex, _fundAmounts, _users);
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("InvalidPoolIndex(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 2));

        vm.prank(users.admin);
        purrVesting.removeFund(poolIndex + 1, _users);
    }

    function test_RemoveFund_VESTING_TYPE_LINEAR_UNLOCK_FIRST_ShouldRevert_WhenInvalidPoolIndex_GreaterThanPoolIndex() public {
        _users = [users.alice, users.bob];
        _fundAmounts = [1e18, 2e18];

        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST,
            uint256(block.timestamp + 1 days),
            1 days,
            1000,
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 1;
        Pool memory _pool = purrVesting.getPoolInfo(poolIndex);

        vm.startPrank(users.admin);
        ERC20Mock(_pool.tokenFund).approve(address(purrVesting), 1000e18);
        purrVesting.addFund(poolIndex, _fundAmounts, _users);
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("InvalidPoolIndex(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 2));

        vm.prank(users.admin);
        purrVesting.removeFund(poolIndex + 1, _users);
    }

    function test_RemoveFund_VESTING_TYPE_MILESTONE_UNLOCK_FIRST_ShouldRevert_WhenInvalidPoolIndex_LessThanOrEqualZero() public {
        _users = [users.alice, users.bob];
        _fundAmounts = [1e18, 2e18];
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST, uint256(block.timestamp + 1 days), 1 days, 1000, 0, times, percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 1;
        Pool memory _pool = purrVesting.getPoolInfo(poolIndex);

        vm.startPrank(users.admin);
        ERC20Mock(_pool.tokenFund).approve(address(purrVesting), 1000e18);
        purrVesting.addFund(poolIndex, _fundAmounts, _users);
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("InvalidPoolIndex(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 0));

        vm.prank(users.admin);
        purrVesting.removeFund(0, _users);
    }

    function test_RemoveFund_VESTING_TYPE_LINEAR_UNLOCK_FIRST_ShouldRevert_WhenInvalidPoolIndex_LessThanOrEqualZero() public {
        _users = [users.alice, users.bob];
        _fundAmounts = [1e18, 2e18];

        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST,
            uint256(block.timestamp + 1 days),
            1 days,
            1000,
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 1;
        Pool memory _pool = purrVesting.getPoolInfo(poolIndex);

        vm.startPrank(users.admin);
        ERC20Mock(_pool.tokenFund).approve(address(purrVesting), 1000e18);
        purrVesting.addFund(poolIndex, _fundAmounts, _users);
        vm.stopPrank();

        bytes4 selector = bytes4(keccak256("InvalidPoolIndex(uint256)"));
        vm.expectRevert(abi.encodeWithSelector(selector, 0));

        vm.prank(users.admin);
        purrVesting.removeFund(0, _users);
    }

    function test_RemoveFund_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldRemoveFund() public {
        _users = [users.alice, users.bob, users.carole];
        _fundAmounts = [1e18, 2e18, 3e18];
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST, uint256(block.timestamp + 1 days), 1 days, 1000, 0, times, percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 1;
        Pool memory _pool = purrVesting.getPoolInfo(poolIndex);

        vm.startPrank(users.admin);
        ERC20Mock(_pool.tokenFund).approve(address(purrVesting), 1000e18);
        purrVesting.addFund(poolIndex, _fundAmounts, _users);
        vm.stopPrank();

        _usersRemove = [users.alice, users.bob];
        _fundAmountsRemove = [1e18, 2e18];
        uint256 length = _usersRemove.length;
        uint256 totalfundAmountsRemove;
        uint256 preTotalRemove;
        uint256 posTotalRemove;
        uint256 prePoolFundsTotal;
        uint256 posPoolFundsTotal;
        uint256 preOwnerBalance;
        uint256 posOwnerBalance;
        uint256 prePurrVestingBalance;
        uint256 posPurrVestingBalance;

        for (uint256 i; i < length;) {
            vm.prank(_usersRemove[i]);
            UserPool memory _userPool = purrVesting.getUserClaimInfo(poolIndex, _users[i]);

            preTotalRemove += _userPool.fund;
            totalfundAmountsRemove += _fundAmountsRemove[i];

            unchecked {
                ++i;
            }
        }
        Pool memory _pool1 = purrVesting.getPoolInfo(poolIndex);
        prePoolFundsTotal = _pool1.fundsTotal;
        preOwnerBalance = ERC20Mock(_pool.tokenFund).balanceOf(users.admin);
        prePurrVestingBalance = ERC20Mock(_pool.tokenFund).balanceOf(address(purrVesting));

        vm.prank(users.admin);
        purrVesting.removeFund(poolIndex, _usersRemove);

        for (uint256 i; i < length;) {
            vm.prank(_usersRemove[i]);
            UserPool memory _userPool = purrVesting.getUserClaimInfo(poolIndex, _users[i]);
            posTotalRemove += _userPool.fund;

            unchecked {
                ++i;
            }
        }
        Pool memory _pool2 = purrVesting.getPoolInfo(poolIndex);
        posPoolFundsTotal = _pool2.fundsTotal;
        posOwnerBalance = ERC20Mock(_pool.tokenFund).balanceOf(users.admin);
        posPurrVestingBalance = ERC20Mock(_pool.tokenFund).balanceOf(address(purrVesting));

        uint256 retrievedTotalRemove = preTotalRemove - posTotalRemove;
        uint256 retrievedPoolFundsTotal = prePoolFundsTotal - posPoolFundsTotal;
        uint256 retrievedOwnerBalance = posOwnerBalance - preOwnerBalance;
        uint256 retrievedPurrVestingBalance = prePurrVestingBalance - posPurrVestingBalance;

        assertEq(retrievedTotalRemove, totalfundAmountsRemove);
        assertEq(retrievedPoolFundsTotal, totalfundAmountsRemove);
        assertEq(retrievedOwnerBalance, totalfundAmountsRemove);
        assertEq(retrievedPurrVestingBalance, totalfundAmountsRemove);
    }

    function test_RemoveFund_VESTING_TYPE_LINEAR_UNLOCK_FIRST_ShouldRemoveFund() public {
        _users = [users.alice, users.bob, users.carole];
        _fundAmounts = [1e18, 2e18, 3e18];

        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST,
            uint256(block.timestamp + 1 days),
            1 days,
            1000,
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 1;
        Pool memory _pool = purrVesting.getPoolInfo(poolIndex);

        vm.startPrank(users.admin);
        ERC20Mock(_pool.tokenFund).approve(address(purrVesting), 1000e18);
        purrVesting.addFund(poolIndex, _fundAmounts, _users);
        vm.stopPrank();

        _usersRemove = [users.alice, users.bob];
        _fundAmountsRemove = [1e18, 2e18];
        uint256 length = _usersRemove.length;
        uint256 totalfundAmountsRemove;
        uint256 preTotalRemove;
        uint256 posTotalRemove;
        uint256 prePoolFundsTotal;
        uint256 posPoolFundsTotal;
        uint256 preOwnerBalance;
        uint256 posOwnerBalance;
        uint256 prePurrVestingBalance;
        uint256 posPurrVestingBalance;

        for (uint256 i; i < length;) {
            vm.prank(_usersRemove[i]);
            UserPool memory _userPool = purrVesting.getUserClaimInfo(poolIndex, _users[i]);

            preTotalRemove += _userPool.fund;
            totalfundAmountsRemove += _fundAmountsRemove[i];

            unchecked {
                ++i;
            }
        }
        Pool memory _pool1 = purrVesting.getPoolInfo(poolIndex);
        prePoolFundsTotal = _pool1.fundsTotal;
        preOwnerBalance = ERC20Mock(_pool.tokenFund).balanceOf(users.admin);
        prePurrVestingBalance = ERC20Mock(_pool.tokenFund).balanceOf(address(purrVesting));

        vm.prank(users.admin);
        purrVesting.removeFund(poolIndex, _usersRemove);

        for (uint256 i; i < length;) {
            vm.prank(_usersRemove[i]);
            UserPool memory _userPool = purrVesting.getUserClaimInfo(poolIndex, _users[i]);
            posTotalRemove += _userPool.fund;

            unchecked {
                ++i;
            }
        }
        Pool memory _pool2 = purrVesting.getPoolInfo(poolIndex);
        posPoolFundsTotal = _pool2.fundsTotal;
        posOwnerBalance = ERC20Mock(_pool.tokenFund).balanceOf(users.admin);
        posPurrVestingBalance = ERC20Mock(_pool.tokenFund).balanceOf(address(purrVesting));

        uint256 retrievedTotalRemove = preTotalRemove - posTotalRemove;
        uint256 retrievedPoolFundsTotal = prePoolFundsTotal - posPoolFundsTotal;
        uint256 retrievedOwnerBalance = posOwnerBalance - preOwnerBalance;
        uint256 retrievedPurrVestingBalance = prePurrVestingBalance - posPurrVestingBalance;

        assertEq(retrievedTotalRemove, totalfundAmountsRemove);
        assertEq(retrievedPoolFundsTotal, totalfundAmountsRemove);
        assertEq(retrievedOwnerBalance, totalfundAmountsRemove);
        assertEq(retrievedPurrVestingBalance, totalfundAmountsRemove);
    }

    function test_RemoveFund_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldEmit_RemoveFundEvent() public {
        _users = [users.alice, users.bob, users.carole];
        _fundAmounts = [1e18, 2e18, 3e18];
        times = [10 days, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percents = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST, uint256(block.timestamp + 1 days), 1 days, 1000, 0, times, percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 1;
        Pool memory _pool = purrVesting.getPoolInfo(poolIndex);

        vm.startPrank(users.admin);
        ERC20Mock(_pool.tokenFund).approve(address(purrVesting), 1000e18);
        purrVesting.addFund(poolIndex, _fundAmounts, _users);
        vm.stopPrank();

        _usersRemove = [users.alice, users.bob];
        _fundAmountsRemove = [1e18, 2e18];

        vm.expectEmit(true, true, false, true);
        emit RemoveFundEvent(poolIndex, _usersRemove);

        vm.prank(users.admin);
        purrVesting.removeFund(poolIndex, _usersRemove);
    }

    function test_RemoveFund_VESTING_TYPE_LINEAR_UNLOCK_FIRST_ShouldEmit_RemoveFundEvent() public {
        _users = [users.alice, users.bob, users.carole];
        _fundAmounts = [1e18, 2e18, 3e18];

        CreatePool memory poolVesting = _createPool(
            VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST,
            uint256(block.timestamp + 1 days),
            1 days,
            1000,
            uint256(block.timestamp + 1 days),
            times,
            percents
        );

        vm.prank(users.admin);
        purrVesting.createPool(poolVesting);

        uint256 poolIndex = 1;
        Pool memory _pool = purrVesting.getPoolInfo(poolIndex);

        vm.startPrank(users.admin);
        ERC20Mock(_pool.tokenFund).approve(address(purrVesting), 1000e18);
        purrVesting.addFund(poolIndex, _fundAmounts, _users);
        vm.stopPrank();

        _usersRemove = [users.alice, users.bob];
        _fundAmountsRemove = [1e18, 2e18];

        vm.expectEmit(true, true, false, true);
        emit RemoveFundEvent(poolIndex, _usersRemove);

        vm.prank(users.admin);
        purrVesting.removeFund(poolIndex, _usersRemove);
    }

    function _createPool(
        VestingType _vestingType,
        uint256 _tge,
        uint256 _cliff,
        uint256 _unlockPercent,
        uint256 _linearVestingDuration,
        uint64[] memory _times,
        uint16[] memory _percents
    )
        internal
        view
        returns (CreatePool memory)
    {
        return CreatePool({
            projectId: "17aa0f02-6ce1-4352-84ab-42bc0fa66d15",
            tokenFund: address(erc20IDO),
            name: "FANX",
            vestingType: _vestingType,
            tge: _tge,
            cliff: _cliff,
            unlockPercent: _unlockPercent,
            linearVestingDuration: _linearVestingDuration,
            times: _times,
            percents: _percents
        });
    }

    function _deal(address _reciever, uint256 _amount) internal {
        vm.prank(_reciever);
        erc20IDO.mint(_amount);
    }
}
