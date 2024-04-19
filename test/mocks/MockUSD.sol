// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MockUSD is ERC20, Ownable {
    constructor(address initialOwner) ERC20("MockUSD", "MUSD") Ownable(initialOwner) { }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
