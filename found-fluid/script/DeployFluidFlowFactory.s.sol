// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {FluidFlowFactory} from "../src/FluidFlowFactory.sol";
import { ISuperfluid } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

contract DeployFluidFlowFactory is Script {
    ISuperfluid host = ISuperfluid(0x109412E3C84f0539b43d39dB691B08c90f58dC7c);
    address constant TRADE_EXECUTOR = 0xD63c3ba1130b584549d82c87C33dF1a1c285b41c;

    function run() external {
        vm.startBroadcast();
        new FluidFlowFactory(host, TRADE_EXECUTOR);
        vm.stopBroadcast();
    }
}