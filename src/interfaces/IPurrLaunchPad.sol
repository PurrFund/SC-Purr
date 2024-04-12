// SPDX-License-Identifer: MIT

pragma solidity ^0.8.20;

import { LaunchPool, LaunchPad, PreProject, Project } from "../types/LaunchPadType.sol";

interface IPurrLaunchPad {
    // event list
    event CreateProject(Project project, LaunchPad launchPad, LaunchPool launchPool);

    /**
     * @notice Create new project.
     *
     * @dev Emit a {CreateProject} event.
     *
     * Requirements:
     * - Require onwner role
     *
     * @param project The project info.
     * @param launchPool The launch pool info.
     * @param launchPad The launch pad info.
     *
     */
    function createProject(PreProject memory project, LaunchPool memory launchPool, LaunchPad memory launchPad) external;
}
