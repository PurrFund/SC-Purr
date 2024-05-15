// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Burnable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Pausable } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IPurrToken } from "../interfaces/IPurrToken.sol";

/**
 * @title PurrToken contract.
 *
 * @notice See document in {IPurrToken} and {IERC20} interfaces .
 */
contract PurrToken is ERC20, ERC20Burnable, ERC20Pausable, Ownable, IPurrToken {
    /**
     * @param _initialOwner The owner address.
     * @param _name The token nanme.
     * @param _symbol The symbol.
     */
    constructor(address _initialOwner, string memory _name, string memory _symbol) ERC20(_name, _symbol) Ownable(_initialOwner) { }

    /**
     * @inheritdoc IPurrToken
     */
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }

    /**
     * @dev Override function transfer from erc20 standard add {whenNotPaused} .
     */
    function transfer(address _to, uint256 _value) public override whenNotPaused returns (bool) {
        return super.transfer(_to, _value);
    }

    /**
     *  @dev Override function transfer from erc20 standard add {whenNotPaused} .
     */
    function approve(address _spender, uint256 _value) public override whenNotPaused returns (bool) {
        return super.approve(_spender, _value);
    }

    /**
     * @dev Override function transfer from erc20 standard add {whenNotPaused}.
     */
    function transferFrom(address _from, address _to, uint256 _value) public override whenNotPaused returns (bool) {
        return super.transferFrom(_from, _to, _value);
    }

    /**
     * @inheritdoc IPurrToken
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @inheritdoc IPurrToken
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     *  @dev The following functions are overrides required by Solidity.
     */
    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
        super._update(from, to, value);
    }
}
