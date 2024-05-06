// SPDX-License_Identifier: UNLICENSED
pragma solidity ^0.8.20; 

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { BaseTest } from "../Base.t.sol";
import {PurrVesting} from "../../src/PurrVesting.sol";
import { PoolState, Pool, UserPool, CreatePool } from "../../src/types/PurrVestingType.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import { VestingType } from "../../src/types/PurrLaunchPadType.sol";

contract PurrVestingTest is BaseTest {
    // ERC20Mock erc20IDO; 
    // PurrVesting purrVesting; 
    // uint256 initBalance; 
    // address[] depositorAddresses; 
    // uint256[] amounts; 

    // event CreatePoolEvent(uint256 poolId, Pool pool);
    // event AddFundEvent(uint256 poolId, address[] user, uint256[] fundAmount);
    // event RemoveFundEvent(uint256 poolId, address[] user);
    // event ClaimFundEvent(uint256 poolId, address user, uint256 fundClaimed);

    // function setUp() public {
    //     initBalance = 100_000e18; 
    //     purrVesting = new PurrVesting(users.admin); 
    //     erc20IDO = new ERC20Mock("FANX", "FTK"); 
    //     _deal(users.admin, initBalance);
    // }

    // function _deal(address _reciever, uint256 _amount) internal {
    //     vm.prank(users.admin);
    //     erc20IDO.mint(_reciever, _amount);
    // }

    // function test_CreatePool_ShouldRevert_WhenNotOwner() public {
    //     bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
    //     vm.expectRevert(abi.encodeWithSelector(selector, users.alice));

    //     CreatePool memory pool = _createPool(VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST, uint256(block.timestamp + 1 days), uint256(120 days),uint256(2555)); 
    //     vm.prank(users.alice);
    //     purrVesting.updateBalanceDepositor(depositorAddresses, amounts);
    // }

    // function test_CreatePool_ShouldRevert_WhenInvalid_TGE_UNLOCKPERCENT_CLIFF() public {

    // }
    
    // function test_CreatePool_ShouldRevert_WhenInvalid_Time_Percent_LinierVestingDuration() public {

    // }

    // function test_CreatePool_ShouldRevert_WhenInvalidCliffTime() public {

    // }

    // function test_CreatePool_ShouldRevert_WhenInvalidTotalPercent() public {

    // }

    // // function test_CreatePool_ShouldRevert_
    // // test revert createPool in else 
    
    // function _createPool(VestingType _vestingType, uint256 _tge,uint256 _cliff,uint256 _unlockPercent,uint256 _linearVestingDuration,uint256[] calldata _times, uint256[] calldata _percents) internal returns(CreatePool memory) {
    //     return CreatePool({
    //         tokenFund: address(erc20IDO),
    //         name: "FANX",
    //         vestingType: _vestingType,
    //         tge: _tge,
    //         cliff: _cliff,
    //         unlockPercent: _unlockPercent,
    //         linearVestingDuration: _linearVestingDuration,
    //         times: _times,
    //         percents: _percents,
    //         fundsTotal: 0,
    //         fundsClaimed: 0,
    //         state: PoolState.INIT
    //     }); 
    // }
}