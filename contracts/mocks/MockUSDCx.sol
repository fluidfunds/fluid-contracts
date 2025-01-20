// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";

contract MockUSDCx is ERC20 {
    constructor() ERC20("Mock USDCx", "USDCx") {
        _mint(msg.sender, 1000000 * 10**18); // Mint 1M tokens
    }

    // Mock the required Superfluid token functions
    function getHost() external pure returns (address) {
        return address(0);
    }

    function getUnderlyingToken() external pure returns (address) {
        return address(0);
    }

    // Override transfer to always succeed in tests
    function transfer(address to, uint256 amount) public override returns (bool) {
        return true;
    }

    // Mock function to mint tokens for testing
    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }
} 