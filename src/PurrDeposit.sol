// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { IPurrDeposit } from "./interfaces/IPurrDeposit.sol";

/**
 * @title PurrDeposit.
 * @notice Track investment amount.
 */
contract PurrDeposit is Ownable, ReentrancyGuard, IPurrDeposit {
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

    modifier onlyRootAdminAndOwner() {
        if (msg.sender != rootAdmin && msg.sender != owner()) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function deposit(uint256 _amount) external nonReentrant {
        address sender = msg.sender;

        if (_amount <= 0) {
            revert InvalidAmount(_amount);
        }

        depositorInfo[msg.sender] += _amount;

        usd.safeTransferFrom(sender, address(this), _amount);

        emit Deposit(sender, _amount, block.timestamp);
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

        usd.safeTransfer(sender, _amount);

        emit WithDrawRootAdmin(address(this), sender, _amount);
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function withDrawUser(uint256 _amount) external nonReentrant {
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

        depositorInfo[sender] -= _amount;

        usd.safeTransfer(sender, _amount);

        emit WithDrawUser(sender, _amount, block.timestamp);
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function updateBalanceDepositor(address[] calldata _depositorAddresses, uint256[] calldata _amounts) external onlyOwner {
        uint256 depositorLength = _depositorAddresses.length;
        uint256 amountLength = _amounts.length;

        if (depositorLength != amountLength) {
            revert InvalidArgument();
        }

        for (uint256 i; i < depositorLength;) {
            uint256 _amount = _amounts[i];

            if (depositorInfo[_depositorAddresses[i]] < _amount) {
                revert InvalidUpdateAmount(_depositorAddresses[i], _amount);
            }

            depositorInfo[_depositorAddresses[i]] = _amount;

            unchecked {
                ++i;
            }
        }
    }
    
    /**
     * @inheritdoc IPurrDeposit
     */
    function turnOffWithDraw() external onlySubAdmin {
        canWithDraw = false;
    }

    /**
     * @inheritdoc IPurrDeposit
     */
    function updateStatusWithDraw(bool _canWithDraw) external onlyOwner {
        canWithDraw = _canWithDraw;
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
