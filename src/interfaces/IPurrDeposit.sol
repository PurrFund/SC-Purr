// SPDX-License-Identier: MIT
pragma solidity ^0.8.20;

interface IPurrDeposit {
    // event list
    event Deposit(address indexed depositor, uint256 amount, uint256 timeDeposit);
    event AddFund(address indexed sender, address indexed receiver, uint256 amount);
    event WithDrawRootAdmin(address indexed sender, address indexed receiver, uint256 amount);
    event WithDrawUser(address indexed sender, uint256 amount, uint256 timeWithDraw);

    // error list
    error InsufficientBalance(uint256 amount);
    error InsufficientTotalSupply(uint256 amount);
    error InvalidAmount(uint256 amount);
    error InvalidSubAdmin(address subAdmin);
    error InvalidRootAdmin(address rootAdmin);
    error CanNotWithDraw();
    error InvalidArgument();
    error InvalidUpdateAmount(address depositor, uint256 amount);

    /**
     * @notice Deposit usd.
     *
     * @dev Will transfer usd to _rootAdmin.
     * @dev Emit a {Deposit} event.
     *
     * Requirements:
     *   - Require sender approve usd for this contract more than {_amount}.
     *
     * @param _amount The amount user will deposit.
     */
    function deposit(uint256 _amount) external;

    /**
     * @notice Add fund to contract.
     *
     * @dev Will transfer usd to this contract to allow user withdraw their investment amount.
     * @dev Emit a {AddFund} event.
     *
     * Requirements:
     *  - Require sender approve usd for this contract.
     *
     * @param _amount The amount add fund.
     */
    function addFund(uint256 _amount) external;

    /**
     * @notice Withdraw usd to rootadmin.
     *
     * @dev Will transfer usd from this contract to rootAdmin.
     * @dev Only rootAdmin can withdraw for secure purpose.
     * @dev Emit a {WithDrawRootAdmin} event.
     *
     * @param _amount The amount add fund.
     */
    function withDrawRootAdmin(uint256 _amount) external;

    /**
     * @notice Withdraw usd from this contract to sender.
     *
     * @dev Will transfer usd to this contract to sender.
     * @dev User can't not withdraw before snapshot time end.
     * @dev Emit a {WithDrawUser} event.
     *
     * @param _amount The amount add fund.
     */
    function withDrawUser(uint256 _amount) external;

    /**
     * @notice Update user balance in contract.
     *
     * @dev We will update user's balance after snapshot that they register.
     * @dev Remain user's balanace based on our calculation in snapshot time.
     * @dev Only owner can call this function.
     *
     * @param _depositorAddresses The array address.
     * @param  _amounts The array amount.
     */
    function updateBalanceDepositor(address[] calldata _depositorAddresses, uint256[] calldata _amounts) external;

    /**
     * @notice Turn off withdraw.
     *
     * @dev We will turn off withdraw mode in snapshot time.
     * @dev User can withdraw when snapshot time end.
     * @dev Only subadmin can call this function.
     */
    function turnOffWithDraw() external;

    /**
     * @notice Update withdraw status.
     *
     * @dev We will update withdraw status.
     * @dev Only owner can call this function.
     *
     * @param _canWithDraw The _canWithDraw staus.
     */
    function updateStatusWithDraw(bool _canWithDraw) external;

    /**
     * @notice Update usd address.
     *
     * @dev We will update usd address.
     * @dev Only owner can call this function.
     *
     * @param _usd The usd address.
     */
    function setUsd(address _usd) external;

    /**
     * @notice Update rootadmin address.
     *
     * @dev We will update rootadmin address.
     * @dev Only rootadmin can call this function.
     *
     * @param rootAdmin_ The rootAdmin address.
     */
    function setRootAdmin(address rootAdmin_) external;
}
