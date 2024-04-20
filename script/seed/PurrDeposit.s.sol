// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { BaseScript } from "../Base.s.sol";
import { PurrDeposit } from "../../src/PurrDeposit.sol";
import { MockUSD } from "../../test/mocks/MockUSD.sol";

contract DeployMockusdScript is BaseScript {
    address rootAdmin = vm.envAddress("ROOT_ADMIN");
    // mock usd
    address usd = 0xcB269E7e42D8728C91CCF840c27A25f11285548f;
    address[] seedAddress = [
        0x9C623EfF30c8BCba288fc0346C44576d3c7FF52C,
        0x1405dC6c6cB6Cb9480F01E3E43a5ec89f680Cb8D,
        0xA9c80A4ece07EAcA61E20c79c7D4DE343A6A3d27,
        0xFFe9F67093c3af3bDB621be78Ed45F5d9CF5200e,
        0x93B7CE2fc14e10b40566a76c17d11045aF9AEe85,
        0x6a8aaE6a359567BA636CC77CD2592849a0E3e56E,
        0xd1024Ee5a24585311F99cbcC18E4F80ad90a04F1,
        0x59c2E42B4275Bf84d653a8A5e5b874BED32688a9
    ];

    function seedDeposit(address _deposit) public broadcast {
        for (uint256 i; i < seedAddress.length; i++) {
            MockUSD(usd).mint(seedAddress[i], i * 1e18 * 1000);
            vm.startPrank(seedAddress[i]);
            MockUSD(usd).approve(_deposit, i * 1e18 * 1000);
            PurrDeposit(_deposit).deposit(i * 1e18);
            vm.stopPrank();
        }
    }
}
