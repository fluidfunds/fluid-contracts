// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {TradeExecutor} from "../src/TradeExecutor.sol";

contract DeployTradeExecutor is Script {
    // Update per network (mainnet/goerli/arbitrum etc)
    address constant UNISWAP_V3_ROUTER = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;

    function run() external {
        vm.startBroadcast();
        TradeExecutor tradeExec = new TradeExecutor(UNISWAP_V3_ROUTER);
        vm.stopBroadcast();
    }
}