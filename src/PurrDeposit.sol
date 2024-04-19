// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { IPurrDeposit } from "./interfaces/IPurrDeposit.sol";

/**
 * @title PurrDeposit.
 * @notice Track investment amount.
 */
contract PurrDeposit is Ownable, IPurrDeposit {
    using SafeERC20 for IERC20;

    address public rootAdmin;
    address public subAdmin;
    bool public canWithDraw;
    IERC20 public usd;

    mapping(address depositor => uint256 amount) public depositorInfo;

    constructor(address _initialOwner, address _usd, address _rootAdmin, address _subAdmin) Ownable(_initialOwner) {
        usd = IERC20(_usd);
        rootAdmin = _rootAdmin;
        subAdmin = _subAdmin;
        canWithDraw = true;
    }

    modifier onlySubAdmin() {
        if (msg.sender != subAdmin) {
            revert InvalidSubAdmin(msg.sender);
        }
        _;
    }

    modifier onlyRootAdmin() {
        if (msg.sender != rootAdmin) {
            revert InvalidRootAdmin(msg.sender);
        }
        _;
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function deposit(uint256 _amount) external {
        address sender = msg.sender;

        if (_amount <= 0) {
            revert InvalidAmount(_amount);
        }

        depositorInfo[msg.sender] += _amount;

        usd.safeTransferFrom(sender, address(this), _amount);

        emit Deposit(sender, address(this), _amount, block.timestamp);
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function addFund(uint256 _amount) external {
        address sender = msg.sender;

        if (_amount <= 0) {
            revert InvalidAmount(_amount);
        }

        usd.safeTransferFrom(sender, address(this), _amount);

        emit AddFund(sender, address(this), _amount);
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function withDrawRootAdmin(uint256 _amount) external onlyRootAdmin {
        address sender = msg.sender;

        if (_amount <= 0) {
            revert InvalidAmount(_amount);
        }

        usd.safeIncreaseAllowance(address(this), _amount);
        usd.safeTransferFrom(address(this), sender, _amount);

        emit WithDrawRootAdmin(address(this), sender, _amount);
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function withDrawUser(uint256 _amount) external {
        address sender = msg.sender;

        if (!canWithDraw) {
            revert CanNotWithDraw();
        }

        if (_amount <= 0) {
            revert InvalidAmount(_amount);
        }

        if (usd.balanceOf(address(this)) < _amount) {
            revert InsufficientTotalSupply(_amount);
        }

        if (depositorInfo[sender] < _amount) {
            revert InsufficientBalance(_amount);
        }

        depositorInfo[msg.sender] -= _amount;

        usd.safeTransferFrom(address(this), sender, _amount);

        emit WithDrawUser(address(this), sender, _amount);
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function updateBalanceDepositor(address[] calldata depositorAddresses, uint256[] calldata amounts) external {
        uint256 depositorLength = depositorAddresses.length;
        uint256 amountLength = amounts.length;

        if (depositorLength != amountLength) {
            revert InvalidArgument();
        }

        for (uint256 i; i < depositorLength;) {
            depositorInfo[depositorAddresses[i]] = amounts[i];

            unchecked {
                ++i;
            }
        }

        emit UpdateBalanceDepositor();
    }
    
    /**
     * @inheritdoc IPurrDeposit
     */

    function turnOffWihDraw() external onlySubAdmin {
        canWithDraw = false;

        emit UpdatePoolDeposit(canWithDraw);
    }

    /**
     *
     */
    function updateStatusWithDraw(bool _canWithDraw) external onlyOwner {
        canWithDraw = _canWithDraw;

        emit UpdatePoolDeposit(canWithDraw);
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function setUsdc(address _usd) external onlyOwner {
        usd = IERC20(_usd);

        emit SetUsd(address(usd));
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function setRootAdmin(address _rootAdmin) external onlyRootAdmin {
        rootAdmin = _rootAdmin;

        emit UpdateRootAdmin(rootAdmin);
    }

    function getBalancePurrDeposit() external view returns (uint256) {
        return usd.balanceOf(address(this));
    }
}
