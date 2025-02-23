// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TradeExecutor} from "../src/TradeExecutor.sol";

contract ExecuteTrade is Script {
    address constant TRADE_EXECUTOR = 0xFdB43deec35e10dd2AC758e63Ef28b337B30270f;
    address constant DAIx = 0x9Ce2062b085A2268E8d769fFC040f6692315fd2c;
    address constant USDCx = 0xb598E6C621618a9f63788816ffb50Ee2862D443B;

    function run() external {
        vm.startBroadcast();
        
        // Approve tokens
        IERC20(DAIx).approve(TRADE_EXECUTOR, 10 ether);
        
        // Execute swap
        TradeExecutor(TRADE_EXECUTOR).executeSwap(
            DAIx,
            USDCx,
            10 ether,
            0,
            3000
        );
        
        vm.stopBroadcast();
    }
}