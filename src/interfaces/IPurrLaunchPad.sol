// SPDX-License-Identifer: MIT

pragma solidity ^0.8.20;

import { LaunchPool, LaunchPad, PreProject, Project } from "../types/PurrLaunchPadType.sol";

interface IPurrLaunchPad {
    // event list
    event CreateProject(Project project, LaunchPad launchPad, LaunchPool launchPool);
    event UpdateProject(Project project, LaunchPad launchPad, LaunchPool launchPool);

    /**
     * @notice Create new project.
     *
     * @dev Emit a {CreateProject} event.
     *
     * Requirements:
     * - Require onwner role
     *
     * @param _project The project info.
     * @param _launchPool The launch pool info.
     * @param _launchPad The launch pad info.
     *
     */
    function createProject(PreProject memory _project, LaunchPool memory _launchPool, LaunchPad memory _launchPad) external;

    /**
     * @notice Update new project.
     *
     * @dev Emit a {UpdateProject} event.
     *
     * Requirements:
     * - Require onwner role
     *
     * @param _projectId The projectId.
     * @param _project The project info.
     * @param _launchPool The launch pool info.
     * @param _launchPad The launch pad info.
     *
     */
    function updateProject(
        uint64 _projectId,
        PreProject memory _project,
        LaunchPool memory _launchPool,
        LaunchPad memory _launchPad
    )
        external;
}
