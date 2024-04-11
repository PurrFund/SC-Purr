// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import { IPurrDeposit } from "./interfaces/IPurrDeposit.sol";

contract PurrDeposit is Ownable, ReentrancyGuard, Pausable, IPurrDeposit {
    using SafeERC20 for IERC20;
    using Math for uint256;

    mapping(address depositor => uint256 amount) depositorInfos;

    IERC20 public usdc;

    constructor(address _initialOwner, address _usdc) Ownable(_initialOwner) {
        usdc = IERC20(_usdc);
    }

    function deposit(uint256 amount) external whenNotPaused nonReentrant {
        address sender = msg.sender;
        if (amount <= 0) {
            revert InvalidAmount(amount);
        }

        if (usdc.allowance(sender, address(this)) < amount) {
            revert InsufficientAllowance();
        }

        depositorInfos[sender] += amount;

        usdc.safeTransferFrom(sender, address(this), amount);

        emit Deposit(sender, address(this), amount, block.timestamp);
    }

    function withDraw(uint256 amount) external whenNotPaused nonReentrant { }

    function setUsdc(address _usdc) external onlyOwner {
        usdc = IERC20(_usdc);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
