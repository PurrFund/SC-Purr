// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { BaseTest } from "../Base.t.sol";
import { PurrLaunchPool } from "../../src/PurrLaunchPool.sol";
import { LaunchPool, LaunchPad, PreProject, Project, VestingType } from "../../src/types/PurrLaunchPoolType.sol";
import { ERC20Mock } from "../mocks/ERC20Mock.sol";

contract PurrLaunchPoolTest is BaseTest {
    event CreateProject(Project project, LaunchPad launchPad, LaunchPool launchPool);
    event UpdateProject(Project project, LaunchPad launchPad, LaunchPool launchPool);

    PurrLaunchPool public purrLaunchPool;

    ERC20Mock tokenIDO = new ERC20Mock("tokenIDO", "IDO");
    ERC20Mock tokenUseToBuy = new ERC20Mock("tokenUseToBuy", "TBuy");

    uint64[] time;
    uint16[] percent;
    uint16 unlockPercent = 1000;

    function getTime(uint256 _time) internal view returns (uint256) {
        return block.timestamp + _time;
    }

    function getPreProject(
        address _owner,
        address _tokenIDO,
        string memory _name,
        string memory _twitter,
        string memory _discord,
        string memory _telegram,
        string memory _website
    )
        internal
        pure
        returns (PreProject memory)
    {
        return PreProject({
            owner: _owner,
            tokenIDO: _tokenIDO,
            name: _name,
            twitter: _twitter,
            discord: _discord,
            telegram: _telegram,
            website: _website
        });
    }

    function getLaunchPad(
        uint16 _unlockPercent,
        uint64 _startTime,
        uint64 _snapshotTime,
        uint64 _autoVestingTime,
        uint64 _vestingTime,
        uint16[] memory _percents,
        uint64[] memory _times,
        uint256 _tge,
        uint256 _cliffTime,
        uint256 _linearTime,
        uint256 _tokenOffer,
        uint256 _tokenPrice,
        uint256 _totalRaise,
        uint256 _ticketSize,
        VestingType _typeVesting
    )
        internal
        pure
        returns (LaunchPad memory)
    {
        return LaunchPad({
            unlockPercent: _unlockPercent,
            startTime: _startTime,
            snapshotTime: _snapshotTime,
            autoVestingTime: _autoVestingTime,
            vestingTime: _vestingTime,
            percents: _percents,
            times: _times,
            tge: _tge,
            cliffTime: _cliffTime,
            linearTime: _linearTime,
            tokenOffer: _tokenOffer,
            tokenPrice: _tokenPrice,
            totalRaise: _totalRaise,
            ticketSize: _ticketSize,
            typeVesting: _typeVesting
        });
    }

    function getLaunchPool(
        uint16 _unlockPercent,
        uint64 _startTime,
        uint64 _snapshotTime,
        uint64 _autoVestingTime,
        uint64 _vestingTime,
        uint16[] memory _percents,
        uint64[] memory _times,
        uint256 _tge,
        uint256 _cliffTime,
        uint256 _linearTime,
        uint256 _tokenReward,
        uint256 _totalAirdrop,
        VestingType _typeVesting
    )
        internal
        pure
        returns (LaunchPool memory)
    {
        return LaunchPool({
            unlockPercent: _unlockPercent,
            startTime: _startTime,
            snapshotTime: _snapshotTime,
            autoVestingTime: _autoVestingTime,
            vestingTime: _vestingTime,
            percents: _percents,
            times: _times,
            tge: _tge,
            cliffTime: _cliffTime,
            linearTime: _linearTime,
            tokenReward: _tokenReward,
            totalAirdrop: _totalAirdrop,
            typeVesting: _typeVesting
        });
    }

    function setUp() public {
        purrLaunchPool = new PurrLaunchPool(users.admin);
    }

    function test_CreateProject_ShouldRevert_WhenNotAuthorized() public {
        PreProject memory preProject =
            getPreProject(users.alice, address(tokenIDO), "Alice", "twitter", "discord", "telegram", "website");
        LaunchPad memory launchPad = getLaunchPad(
            30,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            3 days,
            1 days,
            1 days,
            30,
            30,
            30,
            30,
            VestingType.VESTING_TYPE_LINEAR_CLIFF_FIRST
        );
        LaunchPool memory launchPool = getLaunchPool(
            30,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            3 days,
            3 days,
            3 days,
            30,
            30,
            VestingType.VESTING_TYPE_LINEAR_CLIFF_FIRST
        );
        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.bob));
        vm.startPrank(users.bob);
        purrLaunchPool.createProject(preProject, launchPool, launchPad);
    }

    function test_CreateProject_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldCreateProject() public {
        PreProject memory preProject =
            getPreProject(users.alice, address(tokenIDO), "Alice", "twitter", "discord", "telegram", "website");

        time = [11 days + 1 seconds, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percent = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];

        LaunchPad memory launchPad = getLaunchPad(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days,
            1 days,
            0,
            30,
            30,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );

        LaunchPool memory launchPool = getLaunchPool(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days + 1 seconds,
            1 days,
            0,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );

        vm.prank(users.admin);
        purrLaunchPool.createProject(preProject, launchPool, launchPad);
        purrLaunchPool.launchPadInfo(1);
        purrLaunchPool.launchPoolInfo(1);
        uint64 _projectId = 1;
        assertEq(purrLaunchPool.projectId(), _projectId);

        Project memory project = Project({
            id: _projectId,
            owner: preProject.owner,
            tokenIDO: preProject.tokenIDO,
            name: preProject.name,
            twitter: preProject.twitter,
            discord: preProject.discord,
            telegram: preProject.telegram,
            website: preProject.website
        });

        (
            uint64 _id,
            address _owner,
            address _tokenIDO,
            string memory _name,
            string memory _twitter,
            string memory _discord,
            string memory _telegram,
            string memory _website
        ) = purrLaunchPool.projectInfo(_projectId);
        Project memory retrievedProject = Project({
            id: _id,
            owner: _owner,
            tokenIDO: _tokenIDO,
            name: _name,
            twitter: _twitter,
            discord: _discord,
            telegram: _telegram,
            website: _website
        });
        assertEq(abi.encode(retrievedProject), abi.encode(project));
    }

    function test_CreateProject_VESTING_TYPE_LINEAR_UNLOCK_FIRST_ShouldCreateProject() public {
        PreProject memory preProject =
            getPreProject(users.alice, address(tokenIDO), "Alice", "twitter", "discord", "telegram", "website");

        LaunchPad memory launchPad = getLaunchPad(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days,
            0,
            365 days,
            30,
            30,
            30,
            30,
            VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST
        );

        LaunchPool memory launchPool = getLaunchPool(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days + 1 seconds,
            0,
            365 days,
            30,
            30,
            VestingType.VESTING_TYPE_LINEAR_UNLOCK_FIRST
        );

        vm.prank(users.admin);
        purrLaunchPool.createProject(preProject, launchPool, launchPad);

        uint64 _projectId = 1;
        assertEq(purrLaunchPool.projectId(), _projectId);

        Project memory project = Project({
            id: _projectId,
            owner: preProject.owner,
            tokenIDO: preProject.tokenIDO,
            name: preProject.name,
            twitter: preProject.twitter,
            discord: preProject.discord,
            telegram: preProject.telegram,
            website: preProject.website
        });

        (
            uint64 _id,
            address _owner,
            address _tokenIDO,
            string memory _name,
            string memory _twitter,
            string memory _discord,
            string memory _telegram,
            string memory _website
        ) = purrLaunchPool.projectInfo(_projectId);
        Project memory retrievedProject = Project({
            id: _id,
            owner: _owner,
            tokenIDO: _tokenIDO,
            name: _name,
            twitter: _twitter,
            discord: _discord,
            telegram: _telegram,
            website: _website
        });
        assertEq(abi.encode(retrievedProject), abi.encode(project));
    }

    function test_CreateProject_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldCreateLaunchPad() public {
        time = [11 days + 1 seconds, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percent = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];

        PreProject memory preProject =
            getPreProject(users.alice, address(tokenIDO), "Alice", "twitter", "discord", "telegram", "website");
        LaunchPad memory launchPad = getLaunchPad(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days,
            1 days,
            0,
            30,
            30,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );

        LaunchPool memory launchPool = getLaunchPool(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days + 1 seconds,
            1 days,
            0,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );
        vm.prank(users.admin);
        purrLaunchPool.createProject(preProject, launchPool, launchPad);

        uint64 _projectId = 1;
        assertEq(purrLaunchPool.projectId(), _projectId);

        (
            uint16 _unlockPercent,
            uint64 _startTime,
            uint64 _snapshotTime,
            uint64 _autoVestingTime,
            uint64 _vestingTime,
            uint256 _tge,
            uint256 _cliffTime,
            uint256 _linearTime,
            uint256 _tokenOffer,
            uint256 _tokenPrice,
            uint256 _totalRaise,
            uint256 _ticketSize,
            VestingType _typeVesting
        ) = purrLaunchPool.launchPadInfo(_projectId);

        LaunchPad memory retrievedLaunchPad = LaunchPad({
            unlockPercent: _unlockPercent,
            startTime: _startTime,
            snapshotTime: _snapshotTime,
            autoVestingTime: _autoVestingTime,
            vestingTime: _vestingTime,
            percents: percent,
            times: time,
            tge: _tge,
            cliffTime: _cliffTime,
            linearTime: _linearTime,
            tokenOffer: _tokenOffer,
            tokenPrice: _tokenPrice,
            totalRaise: _totalRaise,
            ticketSize: _ticketSize,
            typeVesting: _typeVesting
        });
        assertEq(abi.encode(retrievedLaunchPad), abi.encode(launchPad));
    }

    function test_CreateProject_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldCreateLaunchPool() public {
        time = [11 days + 1 seconds, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percent = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];

        PreProject memory preProject =
            getPreProject(users.alice, address(tokenIDO), "Alice", "twitter", "discord", "telegram", "website");
        LaunchPad memory launchPad = getLaunchPad(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days,
            1 days,
            0,
            30,
            30,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );

        LaunchPool memory launchPool = getLaunchPool(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days + 1 seconds,
            1 days,
            0,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );

        vm.prank(users.admin);
        purrLaunchPool.createProject(preProject, launchPool, launchPad);

        uint64 _projectId = 1;
        assertEq(purrLaunchPool.projectId(), _projectId);

        (
            uint16 _unlockPercent,
            uint64 _startTime,
            uint64 _snapshotTime,
            uint64 _autoVestingTime,
            uint64 _vestingTime,
            uint256 _tge,
            uint256 _cliffTime,
            uint256 _linearTime,
            uint256 _tokenReward,
            uint256 _totalAirdrop,
            VestingType _typeVesting
        ) = purrLaunchPool.launchPoolInfo(_projectId);

        LaunchPool memory retrievedLaunchPool = LaunchPool({
            unlockPercent: _unlockPercent,
            startTime: _startTime,
            snapshotTime: _snapshotTime,
            autoVestingTime: _autoVestingTime,
            vestingTime: _vestingTime,
            percents: percent,
            times: time,
            tge: _tge,
            cliffTime: _cliffTime,
            linearTime: _linearTime,
            tokenReward: _tokenReward,
            totalAirdrop: _totalAirdrop,
            typeVesting: _typeVesting
        });
        assertEq(abi.encode(retrievedLaunchPool), abi.encode(launchPool));
    }

    function test_CreateProject_VESTING_TYPE_MILESTONE_CLIFF_FIRST_EmitEvent() public {
        time = [11 days + 1 seconds, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percent = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];

        PreProject memory preProject =
            getPreProject(users.alice, address(tokenIDO), "Alice", "twitter", "discord", "telegram", "website");
        LaunchPad memory launchPad = getLaunchPad(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days,
            1 days,
            0,
            30,
            30,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );

        LaunchPool memory launchPool = getLaunchPool(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days + 1 seconds,
            1 days,
            0,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );

        uint64 _projectId = 1;
        Project memory project = Project({
            id: _projectId,
            owner: preProject.owner,
            tokenIDO: preProject.tokenIDO,
            name: preProject.name,
            twitter: preProject.twitter,
            discord: preProject.discord,
            telegram: preProject.telegram,
            website: preProject.website
        });

        vm.expectEmit(true, true, true, true);
        emit CreateProject(project, launchPad, launchPool);

        vm.prank(users.admin);
        purrLaunchPool.createProject(preProject, launchPool, launchPad);
    }

    function test_UpdateProject_ShouldRevert_WhenNotAuthorized() public {
        time = [11 days + 1 seconds, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percent = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];

        PreProject memory preProject =
            getPreProject(users.alice, address(tokenIDO), "Alice", "twitter", "discord", "telegram", "website");
        LaunchPad memory launchPad = getLaunchPad(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days,
            1 days,
            0,
            30,
            30,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );

        LaunchPool memory launchPool = getLaunchPool(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days + 1 seconds,
            1 days,
            0,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );
        vm.prank(users.admin);
        purrLaunchPool.createProject(preProject, launchPool, launchPad);

        uint64 _projectId = 1;

        bytes4 selector = bytes4(keccak256("OwnableUnauthorizedAccount(address)"));
        vm.expectRevert(abi.encodeWithSelector(selector, users.bob));

        vm.prank(users.bob);
        purrLaunchPool.updateProject(_projectId, preProject, launchPool, launchPad);
    }

    function test_UpdateProject_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldUpdateProject() public {
        time = [11 days + 1 seconds, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percent = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];

        PreProject memory preProject =
            getPreProject(users.alice, address(tokenIDO), "Alice", "twitter", "discord", "telegram", "website");
        LaunchPad memory launchPad = getLaunchPad(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days,
            1 days,
            0,
            30,
            30,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );

        LaunchPool memory launchPool = getLaunchPool(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days + 1 seconds,
            1 days,
            0,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );

        vm.prank(users.admin);
        purrLaunchPool.createProject(preProject, launchPool, launchPad);

        PreProject memory preProjectUpdate =
            getPreProject(users.bob, address(tokenIDO), "Bob", "twitter", "discord", "telegram", "website");

        percent = [100, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        LaunchPad memory launchPadUpdate = getLaunchPad(
            unlockPercent - 100,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days,
            1 days,
            0,
            30,
            30,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );
        LaunchPool memory launchPoolUpdate;

        uint64 _projectId = 1;
        assertEq(purrLaunchPool.projectId(), _projectId);

        vm.prank(users.admin);
        purrLaunchPool.updateProject(_projectId, preProjectUpdate, launchPoolUpdate, launchPadUpdate);

        Project memory projectUpdate = Project({
            id: _projectId,
            owner: preProjectUpdate.owner,
            tokenIDO: preProjectUpdate.tokenIDO,
            name: preProjectUpdate.name,
            twitter: preProjectUpdate.twitter,
            discord: preProjectUpdate.discord,
            telegram: preProjectUpdate.telegram,
            website: preProjectUpdate.website
        });

        (
            uint64 _id,
            address _owner,
            address _tokenIDO,
            string memory _name,
            string memory _twitter,
            string memory _discord,
            string memory _telegram,
            string memory _website
        ) = purrLaunchPool.projectInfo(_projectId);
        Project memory retrievedProjectUpdate = Project({
            id: _id,
            owner: _owner,
            tokenIDO: _tokenIDO,
            name: _name,
            twitter: _twitter,
            discord: _discord,
            telegram: _telegram,
            website: _website
        });
        assertEq(abi.encode(retrievedProjectUpdate), abi.encode(projectUpdate));
    }

    function test_UpdateProject_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldUpdateLaunchPad() public {
        time = [11 days + 1 seconds, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percent = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];

        PreProject memory preProject =
            getPreProject(users.alice, address(tokenIDO), "Alice", "twitter", "discord", "telegram", "website");
        LaunchPad memory launchPad = getLaunchPad(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days,
            1 days,
            0,
            30,
            30,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );

        LaunchPool memory launchPool = getLaunchPool(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days + 1 seconds,
            1 days,
            0,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );
        vm.prank(users.admin);
        purrLaunchPool.createProject(preProject, launchPool, launchPad);

        PreProject memory preProjectUpdate =
            getPreProject(users.bob, address(tokenIDO), "Bob", "twitter", "discord", "telegram", "website");

        percent = [100, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];

        LaunchPad memory launchPadUpdate = getLaunchPad(
            unlockPercent - 100,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days,
            1 days,
            0,
            30,
            30,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );
        LaunchPool memory launchPoolUpdate;

        uint64 _projectId = 1;
        assertEq(purrLaunchPool.projectId(), _projectId);

        vm.prank(users.admin);
        purrLaunchPool.updateProject(_projectId, preProjectUpdate, launchPoolUpdate, launchPadUpdate);

        (
            uint16 _unlockPercent,
            uint64 _startTime,
            uint64 _snapshotTime,
            uint64 _autoVestingTime,
            uint64 _vestingTime,
            uint256 _tge,
            uint256 _cliffTime,
            uint256 _linearTime,
            uint256 _tokenOffer,
            uint256 _tokenPrice,
            uint256 _totalRaise,
            uint256 _ticketSize,
            VestingType _typeVesting
        ) = purrLaunchPool.launchPadInfo(_projectId);

        LaunchPad memory retrievedLaunchPadUpdate = LaunchPad({
            unlockPercent: _unlockPercent,
            startTime: _startTime,
            snapshotTime: _snapshotTime,
            autoVestingTime: _autoVestingTime,
            vestingTime: _vestingTime,
            percents: percent,
            times: time,
            tge: _tge,
            cliffTime: _cliffTime,
            linearTime: _linearTime,
            tokenOffer: _tokenOffer,
            tokenPrice: _tokenPrice,
            totalRaise: _totalRaise,
            ticketSize: _ticketSize,
            typeVesting: _typeVesting
        });
        assertEq(abi.encode(retrievedLaunchPadUpdate), abi.encode(launchPadUpdate));
    }

    function test_UpdateProject_VESTING_TYPE_MILESTONE_CLIFF_FIRST_ShouldUpdateLauchPool() public {
        time = [11 days + 1 seconds, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percent = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];

        PreProject memory preProject =
            getPreProject(users.alice, address(tokenIDO), "Alice", "twitter", "discord", "telegram", "website");
        LaunchPad memory launchPad = getLaunchPad(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days,
            1 days,
            0,
            30,
            30,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );

        LaunchPool memory launchPool = getLaunchPool(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days + 1 seconds,
            1 days,
            0,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );

        vm.prank(users.admin);
        purrLaunchPool.createProject(preProject, launchPool, launchPad);

        PreProject memory preProjectUpdate =
            getPreProject(users.bob, address(tokenIDO), "Bob", "twitter", "discord", "telegram", "website");
        percent = [100, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        LaunchPad memory launchPadUpdate = getLaunchPad(
            unlockPercent - 100,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days,
            1 days,
            0,
            30,
            30,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );
        LaunchPool memory launchPoolUpdate = getLaunchPool(
            unlockPercent - 100,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days + 1 seconds,
            1 days,
            0,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );

        uint64 _projectId = 1;
        assertEq(purrLaunchPool.projectId(), _projectId);

        vm.prank(users.admin);
        purrLaunchPool.updateProject(_projectId, preProjectUpdate, launchPoolUpdate, launchPadUpdate);

        (
            uint16 _unlockPercent,
            uint64 _startTime,
            uint64 _snapshotTime,
            uint64 _autoVestingTime,
            uint64 _vestingTime,
            uint256 _tge,
            uint256 _cliffTime,
            uint256 _linearTime,
            uint256 _tokenReward,
            uint256 _totalAirdrop,
            VestingType _typeVesting
        ) = purrLaunchPool.launchPoolInfo(_projectId);

        LaunchPool memory retrievedLaunchPoolUpdate = LaunchPool({
            unlockPercent: _unlockPercent,
            startTime: _startTime,
            snapshotTime: _snapshotTime,
            autoVestingTime: _autoVestingTime,
            vestingTime: _vestingTime,
            percents: percent,
            times: time,
            tge: _tge,
            cliffTime: _cliffTime,
            linearTime: _linearTime,
            tokenReward: _tokenReward,
            totalAirdrop: _totalAirdrop,
            typeVesting: _typeVesting
        });
        assertEq(abi.encode(retrievedLaunchPoolUpdate), abi.encode(launchPoolUpdate));
    }

    function test_UpdateProject_VESTING_TYPE_MILESTONE_CLIFF_FIRST_EmitEvent() public {
        time = [11 days + 1 seconds, 20 days, 30 days, 40 days, 50 days, 60 days, 70 days, 80 days, 90 days, 100 days];
        percent = [0, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];

        PreProject memory preProject =
            getPreProject(users.alice, address(tokenIDO), "Alice", "twitter", "discord", "telegram", "website");
        LaunchPad memory launchPad = getLaunchPad(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days,
            1 days,
            0,
            30,
            30,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );

        LaunchPool memory launchPool = getLaunchPool(
            unlockPercent,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days + 1 seconds,
            1 days,
            0,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );
        vm.prank(users.admin);
        purrLaunchPool.createProject(preProject, launchPool, launchPad);

        PreProject memory preProjectUpdate =
            getPreProject(users.bob, address(tokenIDO), "Bob", "twitter", "discord", "telegram", "website");
        percent = [100, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000];
        LaunchPad memory launchPadUpdate = getLaunchPad(
            unlockPercent - 100,
            2 days,
            3 days,
            6 days,
            10 days,
            percent,
            time,
            10 days,
            1 days,
            0,
            30,
            30,
            30,
            30,
            VestingType.VESTING_TYPE_MILESTONE_CLIFF_FIRST
        );
        LaunchPool memory launchPoolUpdate;
        uint64 _projectId = 1;
        assertEq(purrLaunchPool.projectId(), _projectId);

        Project memory projectUpdate = Project({
            id: _projectId,
            owner: preProjectUpdate.owner,
            tokenIDO: preProjectUpdate.tokenIDO,
            name: preProjectUpdate.name,
            twitter: preProjectUpdate.twitter,
            discord: preProjectUpdate.discord,
            telegram: preProjectUpdate.telegram,
            website: preProjectUpdate.website
        });

        vm.expectEmit(true, true, true, true);
        emit UpdateProject(projectUpdate, launchPadUpdate, launchPoolUpdate);

        vm.prank(users.admin);
        purrLaunchPool.updateProject(_projectId, preProjectUpdate, launchPoolUpdate, launchPadUpdate);
    }
}
