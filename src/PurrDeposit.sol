// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { Pausable } from "@openzeppelin/contracts/utils/Pausable.sol";

import { IPurrDeposit } from "./interfaces/IPurrDeposit.sol";

/**
 * @title PurrDeposit contract.
 *
 * @notice See document in an {IPurrDeposit} interface.
 */
contract PurrDeposit is Ownable, ReentrancyGuard, Pausable, IPurrDeposit {
    using SafeERC20 for IERC20;

    address public rootAdmin;
    address public subAdmin;
    bool public canWithDrawAndDeposit;
    uint256 public totalDeposit;

    IERC20 public usd;

    mapping(address depositor => uint256 amount) public depositorInfo;

    /**
     * @param _initialOwner The initial owner address.
     * @param _usd The usd address.
     * @param _rootAdmin The root admin address.
     * @param _subAdmin The sub admin address.
     */
    constructor(address _initialOwner, address _usd, address _rootAdmin, address _subAdmin) Ownable(_initialOwner) {
        usd = IERC20(_usd);
        rootAdmin = _rootAdmin;
        subAdmin = _subAdmin;
        canWithDrawAndDeposit = true;
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

    modifier onlyRootAdminAndOwner() {
        if (msg.sender != rootAdmin && msg.sender != owner()) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function deposit(uint256 _amount) external whenNotPaused nonReentrant {
        address sender = msg.sender;

        if (_amount <= 0) {
            revert InvalidAmount(_amount);
        }

        if (!canWithDrawAndDeposit) {
            revert CanNotDeposit();
        }

        depositorInfo[msg.sender] += _amount;

        totalDeposit += _amount;

        usd.safeTransferFrom(sender, address(this), _amount);

        emit Deposit(sender, _amount, block.timestamp);
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function addFund(uint256 _amount) external whenNotPaused {
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

        usd.safeTransfer(sender, _amount);

        emit WithDrawRootAdmin(address(this), sender, _amount);
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function withDrawUser(uint256 _amount) external whenNotPaused nonReentrant {
        address sender = msg.sender;

        if (!canWithDrawAndDeposit) {
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

        if (totalDeposit < _amount) {
            revert InsufficientBalance(_amount);
        }

        depositorInfo[sender] -= _amount;

        totalDeposit -= _amount;

        usd.safeTransfer(sender, _amount);

        emit WithDrawUser(sender, _amount, block.timestamp);
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function updateBalanceDepositor(address[] calldata _depositorAddresses, uint256[] calldata _lossAmounts) external onlyOwner {
        uint256 depositorLength = _depositorAddresses.length;
        uint256 amountLength = _lossAmounts.length;
        uint256 totalInvestedAmount;

        // must disable withdraw and deposit feature
        if (canWithDrawAndDeposit) {
            revert InvalidActiveStatus();
        }

        if (depositorLength != amountLength) {
            revert InvalidArgument();
        }

        for (uint256 i; i < depositorLength;) {
            uint256 _amount = _lossAmounts[i];

            if (_amount > depositorInfo[_depositorAddresses[i]]) {
                revert InvalidUpdateAmount(_depositorAddresses[i], _amount);
            }

            depositorInfo[_depositorAddresses[i]] -= _amount;
            totalInvestedAmount += _amount;

            unchecked {
                ++i;
            }
        }

        if (totalInvestedAmount > totalDeposit) {
            revert InvalidInvestedAmount();
        }

        totalDeposit -= totalInvestedAmount;
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function turnOffWithDrawAndDeposit() external onlySubAdmin {
        canWithDrawAndDeposit = false;
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function updateStatusWithDrawAndDeposit(bool _canWithDrawAndDeposit) external onlyOwner {
        canWithDrawAndDeposit = _canWithDrawAndDeposit;
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function setUsd(address _usd) external onlyOwner {
        usd = IERC20(_usd);
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function setRootAdmin(address _rootAdmin) external onlyRootAdmin {
        rootAdmin = _rootAdmin;
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function setSubAdmin(address _subAdmin) external onlyOwner {
        subAdmin = _subAdmin;
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Transfers ownership of the contract to a new account (`newOwner`).
     *
     * @dev Override function {transferOwnership} in {Ownable} contract.
     * @dev Only rootadmin or owner can call this function.
     *
     * @param newOwner The new owner address.
     */
    function transferOwnership(address newOwner) public override onlyRootAdminAndOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }
}
