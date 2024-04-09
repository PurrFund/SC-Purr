// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    uint8 private _decimals;

    constructor(string memory _name, string memory _symbol, uint8 _decimalsNumber) ERC20(_name, _symbol) {
        _decimals = _decimalsNumber;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}
