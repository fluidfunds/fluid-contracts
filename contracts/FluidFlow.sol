// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract FluidFlow {
    address public owner;
    uint256 public totalSupply;
    mapping(address => uint256) public balances;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Mint(address indexed to, uint256 amount);

    constructor() {
        owner = msg.sender;
        totalSupply = 0;
    }

    // Transfer tokens
    function transfer(address to, uint256 amount) public {
        require(to != address(0), "Cannot transfer to zero address");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        balances[msg.sender] -= amount;
        balances[to] += amount;
        emit Transfer(msg.sender, to, amount);
    }

}
