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

    event CreatePoolEvent(uint256 poolId, Pool pool);
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

    function test_CreatePool_ShouldRevert_WhenNotOwner() public {
        // bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        // vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

        // CreatePool memory pool = _createPool(
        //     VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST, uint256(block.timestamp + 1 days), uint256(120 days), uint256(2555)
        // );
        // vm.prank(users.alice);
        // purrVesting.updateBalanceDepositor(depositorAddresses, amounts);
    }

    function test_CreatePool_ShouldRevert_WhenInvalid_TGE_UNLOCKPERCENT_CLIFF() public { }

    function test_CreatePool_ShouldRevert_WhenInvalid_Time_Percent_LinierVestingDuration() public { }

    function test_CreatePool_ShouldRevert_WhenInvalidCliffTime() public { }

    function test_CreatePool_ShouldRevert_WhenInvalidTotalPercent() public { }

    function test_ComputeClaimPercent_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldRight() public {
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
        assertEq(expectPercent1, purrVesting.computeClaimPercent(poolId, block.timestamp));

        vm.warp(createPool.tge + createPool.cliff);
        uint256 expectPercent2 = createPool.unlockPercent;
        uint256 actualPercent2 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent2, actualPercent2);

        vm.warp(times[0] - 1);
        uint256 expectPercent3 = createPool.unlockPercent;
        uint256 actualPercent3 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent3, actualPercent3);

        vm.warp(times[0]);
        uint256 expectPercent4 = createPool.unlockPercent + percents[0];
        uint256 actualPercent4 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent4, actualPercent4);

        vm.warp(times[1] - 1);
        uint256 expectPercent5 = createPool.unlockPercent + percents[0];
        uint256 actualPercent5 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent5, actualPercent5);

        vm.warp(times[1]);
        uint256 expectPercent6 = createPool.unlockPercent + percents[0] + percents[1];
        uint256 actualPercent6 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent6, actualPercent6);

        vm.warp(times[2] - 1);
        uint256 expectPercent7 = createPool.unlockPercent + percents[0] + percents[1];
        uint256 actualPercent7 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent7, actualPercent7);

        vm.warp(times[2]);
        uint256 expectPercent8 = 10_000;
        uint256 actualPercent8 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent8, actualPercent8);

        vm.warp(times[2] + 1 seconds);
        uint256 expectPercent9 = 10_000;
        uint256 actualPercent9 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent9, actualPercent9);
    }

    function test_ComputeClaimPercent_VESTING_TYPE_MILESTONE_UNLOCK_FIRST_ShouldRight() public {
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

        vm.warp(createPool.tge - 1);
        uint256 expectPercent1 = 0;
        assertEq(expectPercent1, purrVesting.computeClaimPercent(poolId, block.timestamp));

        vm.warp(createPool.tge);
        uint256 expectPercent2 = createPool.unlockPercent;
        uint256 actualPercent2 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent2, actualPercent2);

        vm.warp(createPool.tge + createPool.cliff + 1 seconds);
        uint256 expectPercent3 = createPool.unlockPercent;
        uint256 actualPercent3 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent3, actualPercent3);

        vm.warp(times[0] - 1 seconds);
        uint256 expectPercent4 = createPool.unlockPercent;
        uint256 actualPercent4 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent4, actualPercent4);

        vm.warp(times[0]);
        uint256 expectPercent5 = createPool.unlockPercent + percents[0];
        uint256 actualPercent5 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent5, actualPercent5);

        vm.warp(times[1] - 1);
        uint256 expectPercent6 = createPool.unlockPercent + percents[0];
        uint256 actualPercent6 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent6, actualPercent6);

        vm.warp(times[1]);
        uint256 expectPercent7 = createPool.unlockPercent + percents[0] + percents[1];
        uint256 actualPercent7 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent7, actualPercent7);

        vm.warp(times[2] - 1);
        uint256 expectPercent8 = createPool.unlockPercent + percents[0] + percents[1];
        uint256 actualPercent8 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent8, actualPercent8);

        vm.warp(times[2]);
        uint256 expectPercent9 = 10_000;
        uint256 actualPercent9 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent9, actualPercent9);

        vm.warp(times[2] + 1 seconds);
        uint256 expectPercent10 = 10_000;
        uint256 actualPercent10 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent10, actualPercent10);
    }

    function test_ComputeClaimPercent_VESTING_TYPE_LINEAR_UNLOCK_FIRST_ShouldRight() public {
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
        assertEq(expectPercent1, purrVesting.computeClaimPercent(poolId, block.timestamp));

        vm.warp(createPool.tge);
        uint256 expectPercent2 = createPool.unlockPercent;
        uint256 actualPercent2 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent2, actualPercent2);

        vm.warp(createPool.tge + createPool.cliff - 1 seconds);
        uint256 expectPercent3 = createPool.unlockPercent;
        uint256 actualPercent3 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent3, actualPercent3);

        vm.warp(createPool.tge + createPool.cliff + 210 days);
        uint256 expectPercent4 = (block.timestamp - createPool.tge - createPool.cliff).mulDiv(
            10_000 - createPool.unlockPercent, createPool.linearVestingDuration, Math.Rounding.Floor
        ) + createPool.unlockPercent;
        uint256 actualPercent4 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent4, actualPercent4);
    }

    function test_ComputeClaimPercent_VESTING_TYPE_LINEAR_CLIFF_FIRST_ShouldRight() public {
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
        assertEq(expectPercent1, purrVesting.computeClaimPercent(poolId, block.timestamp));

        vm.warp(createPool.tge + createPool.cliff);
        uint256 expectPercent2 = createPool.unlockPercent;
        uint256 actualPercent2 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent2, actualPercent2);

        vm.warp(createPool.tge + createPool.cliff + 210 days);
        uint256 expectPercent4 = (block.timestamp - createPool.tge - createPool.cliff).mulDiv(
            10_000 - createPool.unlockPercent, createPool.linearVestingDuration, Math.Rounding.Floor
        ) + createPool.unlockPercent;
        uint256 actualPercent4 = purrVesting.computeClaimPercent(poolId, block.timestamp);
        assertEq(expectPercent4, actualPercent4);
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

        purrVesting.getPoolInfo(poolId);
        purrVesting.poolInfo(poolId);
        vm.warp(createPool.tge + createPool.cliff);

        uint256 preFundClaimed = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 preUserReleased = purrVesting.getUserClaimInfo(poolId).released;

        vm.startPrank(users.alice);
        uint256 fundPending = purrVesting.getPendingFund(poolId);
        purrVesting.claimFund(poolId);

        uint256 posFundClaimed = purrVesting.getPoolInfo(poolId).fundsClaimed;
        uint256 posUserReleased = purrVesting.getUserClaimInfo(poolId).released;
        vm.stopPrank();

        assertEq(posFundClaimed, preFundClaimed + fundPending);
        assertEq(posUserReleased, preUserReleased + fundPending);
        assertGt(erc20IDO.balanceOf(users.alice), 0);
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
