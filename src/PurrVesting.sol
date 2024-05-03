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
    uint256 public constant ONE_HUNDRED_PERCENT_SCALED = 10_000;
    uint256 public constant TEN_YEARS_IN_S = 311_040_000;

    constructor(address initialOwner) Ownable(initialOwner) { }

    function createPool(
        address _tokenFund,
        string calldata _name,
        uint256 _tge,
        uint256 _cliff,
        uint256 _unlockPercent,
        uint256 _linearVestingDuration,
        VestingType _vestingType,
        uint256[] calldata _milestoneTimes,
        uint256[] calldata _milestonePercents
    )
        external
        nonReentrant
        onlyOwner
    {
        if (uint8(_vestingType) > 3) {
            revert InvalidVestingType();
        }

        if (_tge < block.timestamp || _unlockPercent <= 0 || _unlockPercent > ONE_HUNDRED_PERCENT_SCALED || _cliff < 0) {
            revert InvalidArgCreatePool();
        }

        if (
            _vestingType == VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
                || _vestingType == VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST
        ) {
            if (_milestoneTimes.length != _milestonePercents.length || _milestoneTimes.length < 0 || _linearVestingDuration < 0) {
                revert InvalidArgCreatePool();
            }

            uint256 total = unlockPercent;
            uint256 curTime = 0;

            for (uint256 i; i < _milestoneTimes.length;) {
                total = total + _milestonePercents[i];
                uint256 tmpTime = _milestoneTimes[i];

                if (tmpTime < _tge + _cliff || tmpTime <= curTime) {
                    revert InvalidArgCreatePool();
                }

                curTime = tmpTime;

                unchecked {
                    ++i;
                }
            }

            if (total != ONE_HUNDRED_PERCENT_SCALED) {
                revert InvalidArgCreatePool();
            }
        } else {
            if (
                milestoneTimes.length != 0 || milestonePercents.length != 0 || linearVestingDuration <= 0
                    || linearVestingDuration >= TEN_YEARS_IN_S
            ) {
                revert InvalidArgCreatePool();
            }
        }

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

    function addFund(
        uint256 _poolId,
        uint256[] calldata _fundAmounts,
        address[] calldata _users
    )
        external
        nonReentrant
        onlyOwner
    {
        uint256 userLength = _users.length;
        uint256 fundLength = _fundAmounts.length;
        address sender = msg.sender;

        if (userLength != fundLength) {
            revert InvalidArgument();
        }

        uint256 length = _users.length;
        uint256 totalFundDeposit;

        for (uint256 i = 0; i < length;) {
            address user = _users[i];
            uint256 fundAmount = _fundAmounts[i];
            uint256 oldFund = userPoolInfo[_poolId][user].fund;

            if (oldFund > 0) {
                userPoolInfo[_poolId][user].fund += fundAmount;
            } else {
                userPoolInfo[_poolId][user].fund += fundAmount;
                userPoolInfo[_poolId][user].released = 0;
            }

            totalFundDeposit += fundAmount;

            unchecked {
                ++i;
            }
        }

        poolInfo[poolIndex].fundsTotal += totalFundDeposit;

        IERC20(poolInfo[poolIndex].tokenFund).safeTransferFrom(sender, address(this), totalFundDeposit);

        emit AddFundEvent(_poolId, _users, _fundAmounts);
    }

    function removeFunds(uint256 _poolId, address[] calldata _users) external nonReentrant onlyOwner {
        Pool storage pool = poolInfo[poolId];

        uint256 length = _users.length;

        uint256 totalRemove;

        for (uint256 i = 0; i < length;) {
            address user = _users[i];
            uint256 oldFund = userPoolInfo[_poolId][user].fund;

            if (oldFund > 0) {
                userPoolInfo[_poolId][user].fund = 0;
                userPoolInfo[_poolId][user].released = 0;
                pool.fundsTotal -= oldFund;
                totalRemove += oldFund;
            }

            unchecked {
                ++i;
            }
        }
        IERC20(pool.tokenFund).transfer(_msgSender(), totalRemove);

        emit RemoveFundEvent(_poolId, _users);
    }

    function claimFund(uint256 _poolId) external nonReentrant {
        Pool storage pool = poolInfo[_poolId];
        address sender = msg.sender;

        if (pool.state != PoolState.STARTING) {
            revert InvalidState(pool.state);
        }

        if (userPoolInfo[_poolId][sender].fund <= 0) {
            revert InvalidClaimAmount();
        }

        if (userPoolInfo[_poolId][sender].fund <= userPoolInfo[_poolId][sender].released) {
            revert InvalidFund();
        }

        if (block.timestamp < pool.tge) {
            revert InvalidTime(block.timestamp);
        }

        uint256 claimPercent = computeClaimPercent(_poolId, block.timestamp);

        if (claimPercent <= 0) {
            revert InvalidClaimPercent();
        }

        uint256 claimTotal = userPoolInfo[_poolId][sender].fund.mulDiv(claimPercent, ONE_HUNDRED_PERCENT_SCALED);

        if (claimTotal < userPoolInfo[_poolId][sender].released) {
            revert InvalidClaimAmount();
        }

        uint256 claimAmount = claimTotal - userPoolInfo[_poolId][sender].released;

        userPoolInfo[_poolId][sender].released += claimAmount;
        pool.fundsClaimed += claimAmount;

        IERC20(pool.tokenFund).transfer(sender, claimAmount);

        emit ClaimFundEvent(_poolId, sender, claimAmount);
    }

    function start(uint256 _poolId) external nonReentrant onlyOwner {
        Pool storage pool = poolInfo[_poolId];

        if (pool.state != PoolState.NEW || pool.state != PoolState.PAUSE) {
            revert InvalidState(pool.state);
        }
        pool.state = PoolState.STARTING;
    }

    function pause(uint256 _poolId) external nonReentrant onlyOwner {
        if (poolInfo[_poolId].state == PoolState.PAUSE) {
            revert InvalidState(poolInfo[_poolId].state);
        }

        poolInfo[_poolId].state = PoolState.PAUSE;
    }

    function end(uint256 _poolId) external nonReentrant onlyOwner {
        if (poolInfo[_poolId].state != PoolState.PAUSE) {
            revert InvalidState(poolInfo[_poolId].state);
        }

        poolInfo[_poolId].state = PoolState.SUCCESS;
    }

    function computeClaimPercent(uint256 _poolId, uint256 _now) public view returns (uint256) {
        Pool storage pool = poolInfo[_poolId];

        uint256[] memory milestoneTimes = pool.milestoneTimes;
        uint256[] memory milestonePercents = pool.milestonePercents;

        uint256 totalPercent = 0;
        uint256 tge = pool.tge;
        uint256 milestonesLength = milestoneTimes.length;

        if (pool.vestingType == VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST) {
            if (_now >= tge + pool.cliff) {
                totalPercent += pool.unlockPercent;

                for (uint256 i; i < milestonesLength;) {
                    if (_now >= milestoneTimes[i]) {
                        totalPercent += milestonePercents[i];
                    }
                }

                unchecked {
                    ++i;
                }
            }
        } else if (pool.vestingType == VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST) {
            if (_now >= tge) {
                totalPercent += pool.unlockPercent;
                if (_now >= tge + pool.cliff) {
                    for (uint256 i; i < milestonesLength;) {
                        if (_now >= milestoneTimes[i]) {
                            totalPercent += milestonePercents[i];
                        }
                    }

                    unchecked {
                        ++i;
                    }
                }
            }
        } else if (pool.vestingType == VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST) {
            if (_now >= tge) {
                totalPercent += pool.unlockPercent;
                if (_now >= tge + pool.cliff) {
                    uint256 delta = _now - tge - pool.cliff;

                    totalPercent += (delta.mulDiv(ONE_HUNDRED_PERCENT_SCALED - pool.unlockPercent, pool.linearVestingDuration));
                }
            }
        } else if (pool.vestingType == VestingType.VESTING_TYPE_LINEAR_CLIFF_FIRST) {
            if (_now >= tge + pool.cliff) {
                totalPercent += pool.unlockPercent;
                uint256 delta = _now - tge - pool.cliff;
                totalPercent += (delta.mulDiv(ONE_HUNDRED_PERCENT_SCALED - pool.unlockPercent, pool.linearVestingDuration));
            }
        }
        return (totalPercent < ONE_HUNDRED_PERCENT_SCALED) ? totalPercent : ONE_HUNDRED_PERCENT_SCALED;
    }

    function getFundByUser(uint256 _poolId, address _user) public view returns (uint256, uint256) {
        return (userPoolInfo[_poolId][_user].fund, userPoolInfo[_poolId][_user].released);
    }

    function getInfoUserReward(uint256 _poolId) public view returns (uint256, uint256) {
        Pool storage pool = poolInfo[_poolId];
        uint256 tokenTotal = pool.fundsTotal;
        uint256 claimedTotal = pool.fundsClaimed;

        return (tokenTotal, claimedTotal);
    }

    function getPoolInfo(uint256 _poolId)
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
        Pool memory pool = poolInfo[_poolId];

        return (
            pool.tokenFund,
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
}
