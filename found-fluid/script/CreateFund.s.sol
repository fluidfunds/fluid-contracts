// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {FluidFlowFactory} from "../src/FluidFlowFactory.sol";

contract CreateFund is Script {
    function run() external {
        address factory = vm.envAddress("FACTORY_ADDRESS");
        address tradeExecutor = vm.envAddress("TRADE_EXECUTOR");
        
        vm.startBroadcast();
        FluidFlowFactory(factory).createFund(
            "AlphaFund",
            1000, // 10% fee
            block.timestamp + 7 days,
            30 days,
            tradeExecutor
        );
        vm.stopBroadcast();
    }
}