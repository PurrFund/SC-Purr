// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import { IPurrVesting } from "./interfaces/IPurrVesting.sol";
import { PoolState, Pool, UserPool, CreatePool } from "./types/PurrVestingType.sol";
import { VestingType } from "./types/PurrLaunchPadType.sol";

/**
 * @title PurrVesting contract
 */
contract PurrVesting is Ownable, ReentrancyGuard, Pausable, IPurrVesting {
    using Math for uint256;
    using SafeERC20 for IERC20;

    mapping(uint256 poolIndex => Pool pool) public poolInfo;
    mapping(uint256 poolIndex => mapping(address => UserPool userPool)) public userPoolInfo;

    uint256 public poolIndex;
    uint256 public constant ONE_HUNDRED_PERCENT_SCALED = 10_000;

    constructor(address initialOwner) Ownable(initialOwner) { }

    function createPool(CreatePool calldata _createPool) external onlyOwner {
        if (uint8(_createPool.vestingType) > 3) {
            revert InvalidVestingType();
        }

        if (
            _createPool.tge < block.timestamp || _createPool.unlockPercent <= 0
                || _createPool.unlockPercent > ONE_HUNDRED_PERCENT_SCALED || _createPool.cliff < 0
        ) {
            revert InvalidArgCreatePool();
        }

        if (
            uint8(_createPool.vestingType) == uint8(VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST)
                || uint8(_createPool.vestingType) == uint8(VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST)
        ) {
            if (
                _createPool.times.length != _createPool.percents.length || _createPool.times.length < 0
                    || _createPool.linearVestingDuration != 0
            ) {
                revert InvalidArgCreatePool();
            }

            uint256 total = _createPool.unlockPercent;
            uint256 curTime = 0;

            for (uint256 i; i < _createPool.times.length;) {
                total = total + _createPool.percents[i];
                uint256 tmpTime = _createPool.times[i];

                if (tmpTime < _createPool.tge + _createPool.cliff || tmpTime <= curTime) {
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
            if (_createPool.times.length != 0 || _createPool.percents.length != 0 || _createPool.linearVestingDuration <= 0) {
                revert InvalidArgCreatePool();
            }
        }

        ++poolIndex;
        poolInfo[poolIndex] = Pool({
            id: poolIndex,
            tokenFund: _createPool.tokenFund,
            name: _createPool.name,
            vestingType: _createPool.vestingType,
            tge: _createPool.tge,
            cliff: _createPool.cliff,
            unlockPercent: _createPool.unlockPercent,
            linearVestingDuration: _createPool.linearVestingDuration,
            times: _createPool.times,
            percents: _createPool.percents,
            fundsTotal: 0,
            fundsClaimed: 0,
            state: PoolState.INIT
        });

        emit CreatePoolEvent(poolIndex, poolInfo[poolIndex]);
    }

    function addFund(uint256 _poolId, uint256[] calldata _fundAmounts, address[] calldata _users) external onlyOwner {
        uint256 userLength = _users.length;
        uint256 fundLength = _fundAmounts.length;
        address sender = msg.sender;

        if (userLength != fundLength) {
            revert InvalidArgument();
        }

        if (_poolId > poolIndex || _poolId <= 0) {
            revert InvalidPoolIndex(_poolId);
        }

        uint256 length = _users.length;
        uint256 totalFundDeposit;

        for (uint256 i; i < length;) {
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

    function removeFund(uint256 _poolId, address[] calldata _users) external onlyOwner {
        Pool storage pool = poolInfo[_poolId];

        uint256 length = _users.length;

        if (_poolId > poolIndex || _poolId <= 0) {
            revert InvalidPoolIndex(_poolId);
        }

        uint256 totalRemove;

        for (uint256 i; i < length;) {
            uint256 oldFund = userPoolInfo[_poolId][_users[i]].fund;

            if (oldFund > 0) {
                userPoolInfo[_poolId][_users[i]].fund = 0;
                userPoolInfo[_poolId][_users[i]].released = 0;
                pool.fundsTotal -= oldFund;
                totalRemove += oldFund;
            }

            unchecked {
                ++i;
            }
        }
        IERC20(pool.tokenFund).safeTransfer(msg.sender, totalRemove);

        emit RemoveFundEvent(_poolId, _users);
    }

    function claimFund(uint256 _poolId) external whenNotPaused nonReentrant {
        Pool storage pool = poolInfo[_poolId];
        address sender = msg.sender;

        if (pool.state != PoolState.STARTING) {
            revert InvalidState(pool.state);
        }

        if (userPoolInfo[_poolId][sender].fund <= 0) {
            revert InvalidClaimer(sender);
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

        uint256 claimTotal =
            userPoolInfo[_poolId][sender].fund.mulDiv(claimPercent, ONE_HUNDRED_PERCENT_SCALED, Math.Rounding.Floor);

        if (claimTotal < userPoolInfo[_poolId][sender].released) {
            revert InvalidClaimAmount();
        }

        uint256 claimAmount = claimTotal - userPoolInfo[_poolId][sender].released;

        userPoolInfo[_poolId][sender].released += claimAmount;
        pool.fundsClaimed += claimAmount;

        IERC20(pool.tokenFund).safeTransfer(sender, claimAmount);

        emit ClaimFundEvent(_poolId, sender, claimAmount);
    }

    function start(uint256 _poolId) external onlyOwner {
        Pool storage pool = poolInfo[_poolId];

        if (pool.state != PoolState.INIT && pool.state != PoolState.PAUSE) {
            revert InvalidState(pool.state);
        }

        pool.state = PoolState.STARTING;
    }

    function pause(uint256 _poolId) external onlyOwner {
        if (poolInfo[_poolId].state == PoolState.PAUSE) {
            revert InvalidState(poolInfo[_poolId].state);
        }

        poolInfo[_poolId].state = PoolState.PAUSE;
    }

    function end(uint256 _poolId) external nonReentrant onlyOwner {
        if (poolInfo[_poolId].state != PoolState.PAUSE) {
            revert InvalidState(poolInfo[_poolId].state);
        }

        poolInfo[_poolId].state = PoolState.END;
    }

    function getPendingFund(uint256 _poolId) external whenNotPaused nonReentrant returns (uint256) {
        Pool storage pool = poolInfo[_poolId];
        address sender = msg.sender;

        if (pool.state != PoolState.STARTING) {
            revert InvalidState(pool.state);
        }

        if (userPoolInfo[_poolId][sender].fund <= 0) {
            revert InvalidClaimer(sender);
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

        uint256 claimTotal =
            userPoolInfo[_poolId][sender].fund.mulDiv(claimPercent, ONE_HUNDRED_PERCENT_SCALED, Math.Rounding.Floor);

        if (claimTotal < userPoolInfo[_poolId][sender].released) {
            revert InvalidClaimAmount();
        }

        uint256 claimAmount = claimTotal - userPoolInfo[_poolId][sender].released;

        return claimAmount;
    }

    function computeClaimPercent(uint256 _poolId, uint256 _now) public view returns (uint256) {
        Pool memory pool = poolInfo[_poolId];

        uint64[] memory times = pool.times;
        uint16[] memory percents = pool.percents;

        uint256 totalPercent = 0;
        uint256 tge = pool.tge;
        uint256 milestonesLength = times.length;

        if (uint8(pool.vestingType) == uint8(VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST)) {
            if (_now >= tge + pool.cliff) {
                totalPercent += pool.unlockPercent;

                for (uint256 i; i < milestonesLength;) {
                    if (_now >= times[i]) {
                        totalPercent += percents[i];
                    }

                    unchecked {
                        ++i;
                    }
                }
            }
        } else if (uint8(pool.vestingType) == uint8(VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST)) {
            if (_now >= tge) {
                totalPercent += pool.unlockPercent;
                if (_now >= tge + pool.cliff) {
                    for (uint256 i; i < milestonesLength;) {
                        if (_now >= times[i]) {
                            totalPercent += percents[i];
                        }

                        unchecked {
                            ++i;
                        }
                    }
                }
            }
        } else if (uint8(pool.vestingType) == uint8(VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST)) {
            if (_now >= tge) {
                totalPercent += pool.unlockPercent;
                if (_now >= tge + pool.cliff) {
                    uint256 delta = _now - tge - pool.cliff;

                    totalPercent += (
                        delta.mulDiv(
                            ONE_HUNDRED_PERCENT_SCALED - pool.unlockPercent, pool.linearVestingDuration, Math.Rounding.Floor
                        )
                    );
                }
            }
        } else if (uint8(pool.vestingType) == uint8(VestingType.VESTING_TYPE_LINEAR_CLIFF_FIRST)) {
            if (_now >= tge + pool.cliff) {
                totalPercent += pool.unlockPercent;
                uint256 delta = _now - tge - pool.cliff;
                totalPercent += (
                    delta.mulDiv(ONE_HUNDRED_PERCENT_SCALED - pool.unlockPercent, pool.linearVestingDuration, Math.Rounding.Floor)
                );
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

    function getPoolInfo(uint256 _poolId) public view returns (Pool memory) {
        return poolInfo[_poolId];
    }

    function getUserClaimInfo(uint256 _poolId) external returns (UserPool memory) {
        return userPoolInfo[_poolId][msg.sender];
    }
}
