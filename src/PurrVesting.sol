// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IPurrVesting } from "./interfaces/IPurrVesting.sol";
import { PoolState, Pool, UserPool } from "./types/PurrVestingType.sol";
import { VestingType } from "./types/PurrLaunchPadType.sol";

/**
 * @title PurrVesting contract
 * @notice Vesting fund from sale
 */
contract PurrVesting is Ownable, ReentrancyGuard, IPurrVesting {
    using Math for uint256;
    using SafeERC20 for IERC20;

    mapping(uint256 poolIndex => Pool pool) public poolInfo;
    mapping(uint256 poolIndex => mapping(address => UserPool userPool)) public userPoolInfo;

    uint256 public poolIndex;

    uint8 private constant VESTING_TYPE_MILESTONE_UNLOCK_FIRST = 1;
    uint8 private constant VESTING_TYPE_MILESTONE_CLIFF_FIRST = 2;
    uint8 private constant VESTING_TYPE_LINEAR_UNLOCK_FIRST = 3;
    uint8 private constant VESTING_TYPE_LINEAR_CLIFF_FIRST = 4;

    uint256 private constant ONE_HUNDRED_PERCENT_SCALED = 10_000;
    uint256 private constant TEN_YEARS_IN_S = 311_040_000;

    constructor(address initialOwner) Ownable(initialOwner) {
        poolIndex = 1;
    }

    function createPool(
        address _tokenFund,
        string calldata _name,
        uint8 _vestingType,
        uint256 _tge,
        uint256 _cliff,
        uint256 _unlockPercent,
        uint256 _linearVestingDuration,
        uint256[] calldata _milestoneTimes,
        uint256[] calldata _milestonePercents
    )
        external
        nonReentrant
        onlyOwner
    {
        _validateSetup(_vestingType, _unlockPercent, _tge, _cliff, _linearVestingDuration, _milestoneTimes, _milestonePercents);

        ++poolIndex;
        poolInfo[poolIndex] = Pool({
            id: poolIndex,
            tokenFund: _tokenFund,
            name: _name,
            vestingType: _vestingType,
            tge: _tge,
            cliff: _cliff,
            unlockPercent: _unlockPercent,
            linearVestingDuration: _linearVestingDuration,
            milestoneTimes: _milestoneTimes,
            milestonePercents: _milestonePercents,
            fundsTotal: 0,
            fundsClaimed: 0,
            state: PoolState.NEW
        });

        emit CreatePoolEvent(poolIndex, poolInfo[poolIndex]);
    }

    function start(uint256 poolId) external nonReentrant onlyOwner {
        Pool storage pool = poolInfo[poolId];

        if (pool.state != PoolState.NEW || pool.state != PoolState.PAUSE) {
            revert InvalidState(pool.state);
        }
        pool.state = PoolState.STARTING;
    }

    function pause(uint256 poolId) external nonReentrant onlyOwner {
        if (poolInfo[poolId].state == PoolState.PAUSE) {
            revert InvalidState(poolInfo[poolId].state);
        }

        poolInfo[poolId].state = PoolState.PAUSE;
    }

    function end(uint256 poolId) external nonReentrant onlyOwner {
        if (poolInfo[poolId].state != PoolState.PAUSE) {
            revert InvalidState(poolInfo[poolId].state);
        }

        poolInfo[poolId].state = PoolState.SUCCESS;
    }

    function addFund(uint256 poolId, uint256[] calldata fundAmounts, address[] calldata users) external nonReentrant onlyOwner {
        uint256 userLength = users.length;
        uint256 fundLength = fundAmounts.length;
        address sender = msg.sender;

        if (userLength != fundLength) {
            revert InvalidArgument();
        }

        uint256 length = users.length;
        uint256 totalFundDeposit;

        for (uint256 i = 0; i < length;) {
            address user = users[i];
            uint256 fundAmount = fundAmounts[i];
            uint256 oldFund = userPoolInfo[poolId][user].fund;

            if (oldFund > 0) {
                userPoolInfo[poolId][user].fund += fundAmount;
            } else {
                userPoolInfo[poolId][user].fund += fundAmount;
                userPoolInfo[poolId][user].released = 0;
            }

            totalFundDeposit += fundAmount;

            unchecked {
                ++i;
            }
        }

        poolInfo[poolIndex].fundsTotal += totalFundDeposit; 

        IERC20(poolInfo[poolIndex].tokenFund).safeTransferFrom(sender, address(this), totalFundDeposit);

        emit AddFundEvent(poolId, users, fundAmounts);
    }

    function removeFunds(uint256 poolId, address[] calldata users) external nonReentrant onlyOwner {
        Pool storage pool = poolInfo[poolId];

        uint256 length = users.length;

        uint256 totalRemove;

        for (uint256 i = 0; i < length;) {
            address user = users[i];
            uint256 oldFund = userPoolInfo[poolId][user].fund;

            if (oldFund > 0) {
                userPoolInfo[poolId][user].fund = 0;
                userPoolInfo[poolId][user].released = 0;
                pool.fundsTotal -= oldFund;
                totalRemove += oldFund;
            }

            unchecked {
                ++i;
            }
        }
        IERC20(pool.tokenFund).transfer(_msgSender(), totalRemove);

        emit RemoveFundEvent(poolId, users);
    }

    function claimFund(uint256 poolId) external nonReentrant {
        Pool storage pool = poolInfo[poolId];

        if (pool.state != PoolState.STARTING) {
            revert InvalidState(pool.state);
        }

        if (userPoolInfo[poolId][msg.sender].fund <= 0) {
            revert InvalidClaimAmount();
        }

        if (userPoolInfo[poolId][msg.sender].fund <= userPoolInfo[poolId][msg.sender].released) {
            revert InvalidFund();
        }

        if (block.timestamp < pool.tge) {
            revert InvalidTime(block.timestamp);
        }

        uint256 claimPercent = computeClaimPercent(poolId, block.timestamp);

        if (claimPercent <= 0) {
            revert InvalidClaimPercent();
        }

        uint256 claimTotal = userPoolInfo[poolId][_msgSender()].fund.mulDiv(claimPercent, ONE_HUNDRED_PERCENT_SCALED);

        if (claimTotal < userPoolInfo[poolId][_msgSender()].released) {
            revert InvalidClaimAmount();
        }

        uint256 claimAmount = claimTotal - userPoolInfo[poolId][_msgSender()].released;

        IERC20(pool.tokenFund).transfer(_msgSender(), claimAmount);

        userPoolInfo[poolId][_msgSender()].released += claimAmount;
        pool.fundsClaimed += claimAmount;

        emit ClaimFundEvent(poolId, msg.sender, claimAmount);
    }

    function computeClaimPercent(uint256 poolId, uint256 _now) public view returns (uint256) {
        return 10;
    }

    function getFundByUser(uint256 poolId, address user) public view returns (uint256, uint256) {
        return (userPoolInfo[poolId][user].fund, userPoolInfo[poolId][user].released);
    }

    function getInfoUserReward(uint256 poolId) public view returns (uint256, uint256) {
        Pool storage pool = poolInfo[poolId];
        uint256 tokenTotal = pool.fundsTotal;
        uint256 claimedTotal = pool.fundsClaimed;

        return (tokenTotal, claimedTotal);
    }

    function getPool(uint256 poolId)
        public
        view
        returns (
            address,
            string memory,
            uint8,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256[] memory,
            uint256[] memory,
            uint256,
            uint256,
            PoolState
        )
    {
        Pool storage pool = poolInfo[poolId];
        return (
            address(pool.tokenFund),
            pool.name,
            pool.vestingType,
            pool.tge,
            pool.cliff,
            pool.unlockPercent,
            pool.linearVestingDuration,
            pool.milestoneTimes,
            pool.milestonePercents,
            pool.fundsTotal,
            pool.fundsClaimed,
            pool.state
        );
    }

    function _validateSetup(
        uint8 vestingType,
        uint256 unlockPercent,
        uint256 tge,
        uint256 cliff,
        uint256 linearVestingDuration,
        uint256[] calldata milestoneTimes,
        uint256[] calldata milestonePercents
    )
        private
    {
        // validate set up
    }
}
