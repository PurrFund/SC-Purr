// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { Power, PowerSystem } from "./types/PurrStaingType.sol";

/**
 * @title PurrStaking
 * @notice Tier system and staking model
 */
contract PurrStaking is Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    struct UserPower {
        Power power;
        uint256 balance;
    }

    IERC20 public launchPadToken;
    uint256 public timeLock;

    mapping(address staker => UserPower userPower) public userPower;
    mapping(Power power => PowerSystem powerSystem) public pownerSystem;

    constructor(address _launchPadToken, address _initialOnwer, uint256 _timeLock) Ownable(_initialOnwer) {
        launchPadToken = IERC20(_launchPadToken);
        pownerSystem[Power.ONE] = PowerSystem(1, 100);
        pownerSystem[Power.TWO] = PowerSystem(2, 300);
        pownerSystem[Power.THREE] = PowerSystem(3, 600);
        pownerSystem[Power.FOUR] = PowerSystem(4, 1000);
        pownerSystem[Power.FIVE] = PowerSystem(5, 1500);
        pownerSystem[Power.SIX] = PowerSystem(6, 2100);
        timeLock = _timeLock;
    }

    /**
     * @notice Stake token's protocol.
     *
     * @dev Will update user's power base on user's balance.
     * @dev Emit a {Stake} event.
     *
     * Requirements:
     *   - Require sender approve amount token's staking for this contract more than {amount}.
     *
     * @param amount The amount user will stake.
     *
     * @return status The result of staking.
     */
    function stake(uint256 amount) external returns (bool status) {
        status = _stake(amount);
        return status;
    }

    /**
     * @notice Unstake token's protocol.
     *
     * @dev Will update user's power base on user's balance.
     * @dev Do not transfer {amount} to owner, lock {amount} for {timeLock} before can withdraw.
     * @dev Emit a {UnStake} event.
     *
     * Requirements:
     *   - Amount must be smaller than current balance stake.
     *
     * @param amount The amount user will stake.
     *
     * @return status The result of staking.
     */
    function unstake(uint256 amount) external returns (bool) {
        bool status = _unStake(amount);
        return status;
    }

    // function withDraw() extenal return (bool) {
    //     _withDraw();
    // }

    /**
     * @dev Update power correspond to each value from {Power} enum, and Power.ZERO alway 0
     * Params:
     * - powerList: list amount power, powerList[0] -> Power.ONE and so on sequentially
     * Return (bool) value
     */
    function updatePowerSystem(PowerSystem[] calldata powerList) external onlyOwner returns (bool) {
        pownerSystem[Power.ONE] = powerList[0];
        pownerSystem[Power.TWO] = powerList[1];
        pownerSystem[Power.THREE] = powerList[2];
        pownerSystem[Power.FOUR] = powerList[3];
        pownerSystem[Power.FIVE] = powerList[4];
        pownerSystem[Power.SIX] = powerList[5];

        return true;
    }

    /**
     * @dev Equivalent to {stake} function.
     */
    function _stake(uint256 amount) internal returns (bool) {
        if (launchPadToken.balanceOf(msg.sender) < amount) {
            revert InsufficientAmount(amount);
        }

        // if (amount < launchPadToken.allowance(msg.sender, address(this))) {
        //     revert InsufficientAlowances(amount);
        // }

        userPower[msg.sender].balance.tryAdd(amount);

        IERC20(launchPadToken).safeTransferFrom(msg.sender, address(this), amount);

        Power power = _getPower();
        userPower[msg.sender].power = power;

        emit Stake(msg.sender, amount, block.timestamp, power);

        return true;
    }

    /**
     * @dev Equivalent to {unStake} function.
     */
    function _unStake(uint256 amount) internal returns (bool) {
        uint256 currentBalance = userPower[msg.sender].balance;

        if (amount > currentBalance) {
            revert ExceedBalance(amount);
        }

        userPower[msg.sender].balance.trySub(amount);

        IERC20(launchPadToken).safeTransferFrom(msg.sender, address(this), amount);

        Power power = _getPower();
        userPower[msg.sender].power = power;

        emit UnStake(msg.sender, amount, block.timestamp, power);

        return true;
    }

    /**
     * @dev Get user's power base on user's balance
     */
    function _getPower() internal view returns (Power) {
        uint256 balanceStake = userPower[msg.sender].balance;

        if (balanceStake < pownerSystem[Power.ONE].amount) {
            return Power.ZERO;
        } else if (balanceStake < pownerSystem[Power.TWO].amount) {
            return Power.ONE;
        } else if (balanceStake < pownerSystem[Power.THREE].amount) {
            return Power.TWO;
        } else if (balanceStake < pownerSystem[Power.FOUR].amount) {
            return Power.THREE;
        } else if (balanceStake < pownerSystem[Power.FIVE].amount) {
            return Power.FOUR;
        } else if (balanceStake < pownerSystem[Power.SIX].amount) {
            return Power.FIVE;
        } else if (balanceStake >= pownerSystem[Power.SIX].amount) {
            return Power.SIX;
        }

        return Power.ZERO;
    }

    function _beforeWithDraw() internal { }

    function _afterStaking() internal { }

    // event list
    event Stake(address indexed staker, uint256 amount, uint256 time, Power power);
    event UnStake(address indexed staker, uint256 amount, uint256 time, Power power);

    // error list
    error InsufficientAmount(uint256 amount);
    error InsufficientAlowances(uint256 amount);
    error ExceedBalance(uint256 amount);
}
