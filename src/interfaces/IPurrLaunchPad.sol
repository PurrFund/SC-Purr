// SPDX-License-Identifer: MIT

pragma solidity ^0.8.20;

import { ProjectProfile, Vesting, Project } from "../types/LaunchPadType.sol";

interface IPurrLaunchPad {
    // event list
    event CreateProject(uint256 indexed projectId, Project project, Vesting vesting, ProjectProfile profile);

    // error list
    error InvalidScheduleVesting();
    error InvalidDecimal();
}
