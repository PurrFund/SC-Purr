// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.20;

import { Test } from "forge-std/Test.sol";
import { MockUSD } from "./mocks/MockUSD.sol";

abstract contract BaseTest is Test {
    struct Users {
        address payable admin;
        address payable alice;
        address payable bob;
        address payable carole;
        address payable maker;
        address payable rootAdmin;
        address payable subAdmin;
    }

    uint256 internal constant MAX_UINT256 = type(uint256).max;
    Users internal users;
    MockUSD internal usd;

    constructor() {
        users = Users({
            admin: createUser("Admin"),
            alice: createUser("Alice"),
            bob: createUser("Bob"),
            carole: createUser("Carole"),
            maker: createUser("Maker"),
            rootAdmin: createUser("RootAdmin"),
            subAdmin: createUser("SubAdmin")
        });
    }

    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });
        return user;
    }

    function dealTokens() internal {
        deal({ token: address(usd), to: users.admin, give: 1_000_000e18 });
        deal({ token: address(usd), to: users.alice, give: 1_000_000e18 });
        deal({ token: address(usd), to: users.bob, give: 1_000_000e18 });
        deal({ token: address(usd), to: users.carole, give: 1_000_000e18 });
        deal({ token: address(usd), to: users.maker, give: 1_000_000e18 });
    }

    function deployCore() internal {
        vm.startPrank(users.admin);
        vm.stopPrank();
    }

    function deployCoreWithFork(uint256 fork) internal {
        vm.selectFork(fork);

        vm.startPrank(users.admin);
        vm.stopPrank();
    }
}
