// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

import { IPurrDeposit } from "./interfaces/IPurrDeposit.sol";

/**
 * @title PurrDeposit.
 * @notice Track investment amount.
 */
contract PurrDeposit is Ownable, ReentrancyGuard, AccessControl, IPurrDeposit {
    using SafeERC20 for IERC20;
    using Math for uint256;

    address public rootAdmin;
    IERC20 public usdc;
    bool public canWithDraw;

    constructor(address _initialOwner, address _usdc, address _rootAdmin) Ownable(_initialOwner) {
        usdc = IERC20(_usdc);
        rootAdmin = _rootAdmin;
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function deposit(uint256 _amount) external nonReentrant {
        address sender = msg.sender;
        if (_amount <= 0) {
            revert InvalidAmount(_amount);
        }

        if (usdc.allowance(sender, address(this)) < _amount) {
            revert InsufficientAllowance();
        }

        usdc.safeTransferFrom(sender, rootAdmin, _amount);

        emit Deposit(sender, address(this), _amount, block.timestamp);
    }

    // function setWithDrawStatus()

    /**
     * @inheritdoc IPurrDeposit
     */
    function setUsdc(address _usdc) external onlyOwner nonReentrant {
        usdc = IERC20(_usdc);
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function setRootAdmin(address _rootAdmin) external onlyOwner nonReentrant {
        rootAdmin = _rootAdmin;
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function addFund(uint256 _amount) external {
        address sender = msg.sender;

        if (usdc.balanceOf(sender) < _amount) {
            revert InsufficientBalance(_amount);
        }

        if (usdc.allowance(sender, address(this)) < _amount) {
            revert InsufficientAllowance();
        }

        usdc.safeTransferFrom(sender, address(this), _amount);

        emit AddFund(sender, address(this), _amount);
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function withDraw(uint256 _amount) external onlyOwner {
        address sender = msg.sender;

        if (usdc.balanceOf(address(this)) < _amount) {
            revert InsufficientBalance(_amount);
        }

        usdc.safeTransferFrom(address(this), sender, _amount);

        emit WithDraw(address(this), sender, _amount);
    }
}
