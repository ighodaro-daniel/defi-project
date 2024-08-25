//SPDX-License-Identifier : MIT

pragma solidity ^0.8.19;

/**
 * @title Decentralised stable coin
 * @author Daniel Ighodaro
 * collateral: exogenous(eth & btc)
 * Minting: Algorithmic
 * relative stability: pegged to USD
 *
 * this contract is meant to be ,governed by dscEgine, the contract is an implentation of our stable coin system
 */
import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract DecentralisedStableCoin is ERC20Burnable, Ownable {
    error DecentralisedToken_MustNotBeZero();
    error DecentralisedToken_MustNotExceedBalance();
    error DecentralisedStableCoin_MustBeMoreThanZero();
    error DecentralisedStableCoin_MustNotBeZeroAddress();

    constructor() ERC20("decentraliseStableCoin", "DSC") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (_amount < 0) {
            revert DecentralisedToken_MustNotBeZero();
        }
        if (balance < _amount) {
            revert DecentralisedToken_MustNotExceedBalance();
        }
        super.burn(_amount);
    }

    function mintStableCoin(address _to, uint256 amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert DecentralisedStableCoin_MustNotBeZeroAddress();
        }
        if (amount <= 0) {
            revert DecentralisedStableCoin_MustBeMoreThanZero();
        }
        _mint(_to, amount);
        return true;
    }
}
