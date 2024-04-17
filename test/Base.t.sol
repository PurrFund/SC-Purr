// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.20;

import { Test } from "forge-std/Test.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract BaseTest is Test {
    struct Users {
        address payable admin;
        address payable alice;
        address payable bob;
        address payable carole;
        address payable maker;
    }

    uint256 internal constant MAX_UINT256 = type(uint256).max;
    Users internal users;
    IERC20 internal usdc;

    constructor() {
        users = Users({
            admin: createUser("Admin"),
            alice: createUser("Alice"),
            bob: createUser("Bob"),
            carole: createUser("Carole"),
            maker: createUser("Maker")
        });
    }

    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });
        return user;
    }

    function dealTokens(IERC20 _usdc, address _to) internal {
        deal({ token: address(_usdc), to: _to, give: 1000 * 1e18 });
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
