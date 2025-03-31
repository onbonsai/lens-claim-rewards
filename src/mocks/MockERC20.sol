// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

/**
 * @dev A simple mock currency to be used for testing.
 */
contract MockERC20 is ERC20("Currency", "MCY") {
    uint8 _decimals = 18;

    function testMockCurrency() public {
        // Prevents being counted in Foundry Coverage
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setDecimals(uint8 decimals_) external {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
