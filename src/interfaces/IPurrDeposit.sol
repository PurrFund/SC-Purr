// SPDX-License-Identier: MIT
pragma solidity ^0.8.20;

interface IPurrDeposit {
    // event list
    event Deposit(address indexed depositor, address indexed receiver, uint256 amount, uint256 timeDeposit);
    event AddFund(address indexed admin, address indexed receiver, uint256 amount);
    event WithDraw(address indexed sender, address indexed receiver, uint256 amount);
    event UpdatePoolDeposit(bool canWithDraw);
    event SetUsd(address usd);
    event UpdateRootAdmin(address rootAdmin);
    event WithDrawRootAdmin(address indexed sender, address indexed receiver, uint256 amount);
    event UpdateBalanceDepositor();
    event WithDrawUser(address indexed sender, address indexed receiver, uint256 amount);

    // error list
    error InsufficientAllowance();
    error InsufficientBalance(uint256 amount);
    error InsufficientTotalSupply(uint256 amount);
    error InvalidAmount(uint256 amount);
    error InvalidSubAdmin(address subAdmin);
    error InvalidRootAdmin(address rootAdmin);
    error InvalidAdmin(address admin);
    error CanNotWithDraw();
    error InvalidArgument();

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
     * @param _amount The amount to withdraw.
     */
    function withDrawRootAdmin(uint256 _amount) external;

    /**
     * @notice With draw fund to user.
     * @param _amount The amount to withdraw.
     */
    function withDrawUser(uint256 _amount) external;

    /**
     * @notice Turn off with draw.
     */
    function turnOffWihDraw() external;

    /**
     * @notice Turn off with draw.
     */
    function turnOfWithDraw(bool _canWithDraw) external;
    /**
     * @notice Update depositor's amount deposit in contract.
     *
     * @dev Emit {}
     */
    function updateBalanceDepositor(address[] calldata depositorAddresses, uint256[] calldata amounts) external;
}
