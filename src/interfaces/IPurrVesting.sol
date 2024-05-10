// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { PoolState, Pool, CreatePool, UserPool } from "../types/PurrVestingType.sol";

interface IPurrVesting {
    // event list
    event CreatePoolEvent(Pool pool);
    event AddFundEvent(uint256 poolId, address[] user, uint256[] fundAmount);
    event RemoveFundEvent(uint256 poolId, address[] user);
    event ClaimFundEvent(uint256 poolId, address user, uint256 fundClaimed);

    // error list
    error InvalidState(PoolState state);
    error InvalidArgument();
    error InvalidTime(uint256 timestamp);
    error InvalidClaimPercent();
    error InvalidClaimAmount();
    error InvalidFund();
    error InvalidVestingType();
    error InvalidArgCreatePool();
    error InvalidPoolIndex(uint256 poolId);
    error InvalidClaimer(address claimer);
    error InvalidArgPercentCreatePool();
    error InvalidArgMileStoneCreatePool();
    error InvalidArgTotalPercentCreatePool();
    error InvalidArgLinearCreatePool();

    /**
     * @notice Create new pool vesting.
     *
     * @dev Emit a {CreatePoolEvent} event.
     *
     * Requirements:
     *  - The `msg.sender` must be owner.
     *  - All params must be valited with requirement. See on code.
     *
     * @param _createPool See struct {CreatePool} in {IPurrVesting}.
     */
    function createPool(CreatePool calldata _createPool) external;

    /**
     * @notice Add IDO's amount token base on calculate of auto vesting to corresponding user.
     *
     * @dev Emit a {AddFundEvent} event.
     * @dev  _fundAmounts[i] is correspoinding to _users[i].
     *
     * Requirements:
     *  - The `msg.sender` mus be owner.
     *  - The  `msg.sender` must be approve sum of param {_fundAmounts} IDO token for contract vesing.
     *
     * @param _poolId The poolId onchain.
     * @param _fundAmounts The list fundAmounts.
     * @param _users The list users win the IDO.
     */
    function addFund(uint256 _poolId, uint256[] calldata _fundAmounts, address[] calldata _users) external;

    /**
     * @notice Remove user from list the IDO winners.
     *
     * @dev Emit a {RemoveFundEvent} event.
     *
     * Requirements:
     *  - The `msg.sender` must be owner.
     *
     * @param _poolId The poolId onchain.
     * @param _users The list users wil remove from list the IDO winners.
     */
    function removeFund(uint256 _poolId, address[] calldata _users) external;

    /**
     * @notice User claim their token IDO with vesting strategy.
     *
     * @dev Emit a {ClaimFundEvent} event.
     * @dev Amount be claimed will follow on vesting strategy.
     * @dev Only user won IDO can active this function.
     * @dev User only can claim when pool is starting.
     *
     * @param _poolId The poolId onchain.
     */
    function claimFund(uint256 _poolId) external;

    /**
     * @notice Start pool vesing.
     *
     * Requirements:
     *  - The `msg.sender` must be owner.
     *
     * @param _poolId The poolId onchain.
     */
    function start(uint256 _poolId) external;

    /**
     * @notice Pause pool vesing.
     *
     * Requirements:
     *  - The `msg.sender` must be owner.
     *
     * @param _poolId The poolId onchain.
     */
    function pause(uint256 _poolId) external;

    /**
     * @notice End pool vesing.
     *
     * Requirements:
     *  - The `msg.sender` must be owner.
     *
     * @param _poolId The poolId onchain.
     */
    function end(uint256 _poolId) external;

    /**
     * @notice Get pending fund of IDO.
     *
     * @param _poolId The poolId onchain.
     * @param _claimer The claimer address.
     *
     * @return The current pending fund.
     */
    function getPendingFund(uint256 _poolId, address _claimer) external returns (uint256);

    /**
     * @notice Get current available percent for claiming of IDO.
     *
     * @param _poolId The poolId onchain.
     *
     * @return The current available claim percent.
     */
    function getCurrentClaimPercent(uint256 _poolId) external returns (uint256);

    /**
     * @notice Get pool vesting infomation.
     *
     * @param _poolId The poolId onchain.
     *
     * @return The pool information.
     */
    function getPoolInfo(uint256 _poolId) external returns (Pool memory);

    /**
     * @notice Get user infomation in pool with {_poolId}
     *
     * @param _poolId The poolId onchain.
     * @param _user The user address.
     *
     * @return The user infomation belong pool with {_poolId}.
     */
    function getUserClaimInfo(uint256 _poolId, address _user) external returns (UserPool memory);
}
