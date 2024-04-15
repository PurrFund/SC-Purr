// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { LaunchPool, LaunchPad, PreProject, Project } from "./types/LaunchPadType.sol";
import { IPurrLaunchPad } from "./interfaces/IPurrLaunchPad.sol";

/**
 * @notice PurrLaunchPad contract.
 */
contract PurrLaunchPad is Ownable, IPurrLaunchPad {
    using SafeERC20 for IERC20;

    uint64 public projectId;

    mapping(uint64 projectId => Project project) public projectInfo;
    mapping(uint64 projectId => LaunchPool launchPool) public launchPoolInfo;
    mapping(uint64 projectId => LaunchPad launchPad) public launchPadInfo;

    constructor(address initialOwner) Ownable(initialOwner) { }

    /**
     * @inheritdoc IPurrLaunchPad
     */
    function createProject(
        PreProject memory project,
        LaunchPool memory launchPool,
        LaunchPad memory launchPad
    )
        external
        onlyOwner
    {
        ++projectId;
        projectInfo[projectId] = Project({
            id: projectId,
            owner: project.owner,
            tokenIDO: project.tokenIDO,
            name: project.name,
            twitter: project.twitter,
            discord: project.discord,
            telegram: project.telegram,
            website: project.website
        });

        launchPoolInfo[projectId] = launchPool;
        launchPadInfo[projectId] = launchPad;

        emit CreateProject(projectInfo[projectId], launchPad, launchPool);
    }
}
