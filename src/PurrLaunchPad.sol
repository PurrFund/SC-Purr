// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { LaunchPool, LaunchPad, PreProject, Project, VestingType } from "./types/PurrLaunchPadType.sol";
import { IPurrLaunchPad } from "./interfaces/IPurrLaunchPad.sol";

/**
 * @notice PurrLaunchPad contract.
 */
contract PurrLaunchPad is Ownable, IPurrLaunchPad {
    using SafeERC20 for IERC20;

    uint256 public constant ONE_HUNDRED_PERCENT_SCALED = 10_000;
    uint64 public projectId;

    mapping(uint64 projectId => Project project) public projectInfo;
    mapping(uint64 projectId => LaunchPool launchPool) public launchPoolInfo;
    mapping(uint64 projectId => LaunchPad launchPad) public launchPadInfo;

    /**
     * @param _initialOwner The initial owner.
     */
    constructor(address _initialOwner) Ownable(_initialOwner) { }

    /**
     * @inheritdoc IPurrLaunchPad
     */
    function createProject(
        PreProject memory _project,
        LaunchPool memory _launchPool,
        LaunchPad memory _launchPad
    )
        external
        onlyOwner
    {
        _validateLaunchPad(_launchPad);
        _validateLaunchPool(_launchPool);

        ++projectId;
        projectInfo[projectId] = Project({
            id: projectId,
            owner: _project.owner,
            tokenIDO: _project.tokenIDO,
            name: _project.name,
            twitter: _project.twitter,
            discord: _project.discord,
            telegram: _project.telegram,
            website: _project.website
        });

        launchPoolInfo[projectId] = _launchPool;
        launchPadInfo[projectId] = _launchPad;

        emit CreateProject(projectInfo[projectId], _launchPad, _launchPool);
    }

    /**
     * @inheritdoc IPurrLaunchPad
     */
    function updateProject(
        uint64 _projectId,
        PreProject memory _project,
        LaunchPool memory _launchPool,
        LaunchPad memory _launchPad
    )
        external
        onlyOwner
    {
        _validateLaunchPad(_launchPad);
        _validateLaunchPool(_launchPool);

        projectInfo[_projectId] = Project({
            id: _projectId,
            owner: _project.owner,
            tokenIDO: _project.tokenIDO,
            name: _project.name,
            twitter: _project.twitter,
            discord: _project.discord,
            telegram: _project.telegram,
            website: _project.website
        });

        launchPoolInfo[projectId] = _launchPool;
        launchPadInfo[projectId] = _launchPad;

        emit UpdateProject(projectInfo[projectId], _launchPad, _launchPool);
    }

    /**
     * @inheritdoc IPurrLaunchPad
     */
    function getProjectInfo(uint64 _projectId) external view returns (Project memory, LaunchPad memory, LaunchPool memory) {
        return (projectInfo[_projectId], launchPadInfo[projectId], launchPoolInfo[projectId]);
    }

    /**
     * @dev Validate {_launchPad} field.
     *
     * @param _launchPad The launchpad information.
     */
    function _validateLaunchPad(LaunchPad memory _launchPad) public pure {
        if (uint8(_launchPad.typeVesting) > 3) {
            revert InvalidVestingType();
        }

        if (
            _launchPad.tge < _launchPad.vestingTime || _launchPad.unlockPercent < 0
                || _launchPad.unlockPercent > ONE_HUNDRED_PERCENT_SCALED || _launchPad.cliffTime < 0
        ) {
            revert InvalidArgPercentCreatePool();
        }

        if (
            uint8(_launchPad.typeVesting) == uint8(VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST)
                || uint8(_launchPad.typeVesting) == uint8(VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST)
        ) {
            if (
                _launchPad.times.length != _launchPad.percents.length || _launchPad.times.length < 0 || _launchPad.linearTime != 0
            ) {
                revert InvalidArgCreatePool();
            }

            uint256 total = _launchPad.unlockPercent;
            uint256 curTime = 0;

            for (uint256 i; i < _launchPad.times.length;) {
                total = total + _launchPad.percents[i];
                uint256 tmpTime = _launchPad.times[i];

                if (tmpTime < _launchPad.tge + _launchPad.cliffTime || tmpTime <= curTime) {
                    revert InvalidArgMileStoneCreatePool();
                }

                curTime = tmpTime;

                unchecked {
                    ++i;
                }
            }

            if (total != ONE_HUNDRED_PERCENT_SCALED) {
                revert InvalidArgTotalPercentCreatePool();
            }
        } else {
            if (_launchPad.times.length != 0 || _launchPad.percents.length != 0 || _launchPad.linearTime <= 0) {
                revert InvalidArgLinearCreatePool();
            }
        }
    }

    /**
     * @dev Validate {_launchPool} field if exist.
     *
     * @param _launchPool The launchpool information.
     */
    function _validateLaunchPool(LaunchPool memory _launchPool) public pure {
        if (_launchPool.startTime > 0) {
            if (uint8(_launchPool.typeVesting) > 3) {
                revert InvalidVestingType();
            }

            if (
                _launchPool.tge < _launchPool.vestingTime || _launchPool.unlockPercent < 0
                    || _launchPool.unlockPercent > ONE_HUNDRED_PERCENT_SCALED || _launchPool.cliffTime < 0
            ) {
                revert InvalidArgPercentCreatePool();
            }

            if (
                uint8(_launchPool.typeVesting) == uint8(VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST)
                    || uint8(_launchPool.typeVesting) == uint8(VestingType.VESTING_TYPE_MILESTONE_UNLOCK_FIRST)
            ) {
                if (
                    _launchPool.times.length != _launchPool.percents.length || _launchPool.times.length < 0
                        || _launchPool.linearTime != 0
                ) {
                    revert InvalidArgCreatePool();
                }

                uint256 total = _launchPool.unlockPercent;
                uint256 curTime = 0;

                for (uint256 i; i < _launchPool.times.length;) {
                    total = total + _launchPool.percents[i];
                    uint256 tmpTime = _launchPool.times[i];

                    if (tmpTime < _launchPool.tge + _launchPool.cliffTime || tmpTime <= curTime) {
                        revert InvalidArgMileStoneCreatePool();
                    }

                    curTime = tmpTime;

                    unchecked {
                        ++i;
                    }
                }

                if (total != ONE_HUNDRED_PERCENT_SCALED) {
                    revert InvalidArgTotalPercentCreatePool();
                }
            } else {
                if (_launchPool.times.length != 0 || _launchPool.percents.length != 0 || _launchPool.linearTime <= 0) {
                    revert InvalidArgLinearCreatePool();
                }
            }
        }
    }
}
