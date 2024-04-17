// SPDX-License-Identier: MIT
pragma solidity ^0.8.20;

interface IPurrDeposit {
    // event list
    event Deposit(address indexed depositor, address indexed receiver, uint256 amount, uint256 timeDeposit);
    event AddFund(address indexed admin, address indexed receiver, uint256 amount);
    event WithDraw(address indexed sender, address indexed receiver, uint256 amount);

    // error list
    error InvalidAmount(uint256 amount);
    error InsufficientAllowance();
    error InsufficientBalance(uint256 amount);

    /**
     * @notice Deposit usdc.
     *
     * @dev Will transfer usdc to _rootAdmin.
     * @dev Emit a {Deposit} event.
     *
     * Requirements:
     *   - Require sender approve amount usdc for this contract more than {_amount}.
     *
     * @param _amount The amount user will deposit.
     */
    function deposit(uint256 _amount) external;

    /**
     * @notice Set usdc.
     * @param _usdc The usdc address.
     */
    function setUsdc(address _usdc) external;

    /**
     * @notice Set rootAdmin.
     * @param rootAdmin_ The rootAdmin address.
     */
    function setRootAdmin(address rootAdmin_) external;

    /**
     * @notice Add fund to contract.
     * @param _amount The amount add to contract.
     */
    function addFund(uint256 _amount) external;

    /**
     * @notice With draw to owner.
     * @param _amount The amount withdraw to owner.
     */
    function withDraw(uint256 _amount) external;
}
