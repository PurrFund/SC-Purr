// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ProjectProfile, Vesting, Project } from "./types/LaunchPadType.sol";
import { IPurrLaunchPad } from "./interfaces/IPurrLaunchPad.sol";

contract PurrLaunchPad is Ownable, IPurrLaunchPad {
    using SafeERC20 for IERC20;

    uint64 public projectId;

    mapping(uint64 projectId => Project project) public projectInfo;
    mapping(uint64 projectId => Vesting vesting) public vestingInfo;
    mapping(uint64 projectId => ProjectProfile profile) public projectProfile;

    constructor(address initialOwner) Ownable(initialOwner) { }

    function createProject(
        Project memory project,
        Vesting memory vesting,
        ProjectProfile memory profile
    )
        external
        onlyOwner
        returns (bool)
    {
        _createProject(project, vesting, profile);

        return true;
    }

    /**
     * @dev Create new project
     */
    function _createProject(
        Project memory project,
        Vesting memory vesting,
        ProjectProfile memory profile
    )
        internal
        returns (bool)
    {
        if (vesting.tge <= block.timestamp || vesting.cliffTime <= 0 || vesting.unlockPercent <= 100) {
            revert InvalidScheduleVesting();
        }

        if (project.tokenIdoDeciamls <= 0 || project.tokenDecimals <= 0) {
            revert InvalidDecimal();
        }

        ++projectId;
        projectInfo[projectId] = project;
        vestingInfo[projectId] = vesting;
        projectProfile[projectId] = profile;

        emit CreateProject(projectId, project, vesting, profile);

        return true;
    }
}
