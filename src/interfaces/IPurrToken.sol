// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20;

/**
 * @title IPurrToken interface.
 */
interface IPurrToken {
    /**
     * @notice Will pause approve, transfer, transferFrom action of contract.
     *
     * @dev Emit a {Paused} event.
     *
     * Requirements:
     * - `msg.sender` must be owner of contract.
     */
    function pause() external;

    /**
     * @notice Will unpause approve, transfer, transferFrom action of contract.
     *
     * @dev Emit a {Paused} event.
     *
     * Requirements:
     * - `msg.sender` must be owner of contract.
     */
    function unpause() external;

    /**
     * @notice Mint purr token.
     *
     * Requirements:
     * - `msg.sender` must be owner of contract.
     */
    function mint(address _to, uint256 _amount) external;
}
