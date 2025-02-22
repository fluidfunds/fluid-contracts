// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {FluidFlowFactory} from "../src/FluidFlowFactory.sol";

contract DeployFluidFlowFactory is Script {
    // Network-specific addresses
    address constant USDCX = 0xb598E6C621618a9f63788816ffb50Ee2862D443B;
    address constant TRADE_EXECUTOR = 0xFdB43deec35e10dd2AC758e63Ef28b337B30270f;

    function run() external {
        vm.startBroadcast();
        new FluidFlowFactory(USDCX, TRADE_EXECUTOR);
        vm.stopBroadcast();
    }
}