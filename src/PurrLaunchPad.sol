// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { LaunchPool, LaunchPad, PreProject, Project } from "./types/PurrLaunchPadType.sol";
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
        PreProject memory _project,
        LaunchPool memory _launchPool,
        LaunchPad memory _launchPad
    )
        external
        onlyOwner
    {
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
}
