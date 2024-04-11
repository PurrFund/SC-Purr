// SPDX-License-Identier: MIT
pragma solidity ^0.8.20;

interface IPurrDeposit {
    // event list
    event Deposit(address indexed depositor, address indexed receiver, uint256 amount, uint256 timeDeposit);

    // error list
    error InvalidAmount(uint256 amount);
    error InsufficientAllowance();
    
}
