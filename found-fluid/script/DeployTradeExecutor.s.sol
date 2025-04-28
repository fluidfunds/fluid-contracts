// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {TradeExecutor} from "../src/TradeExecutor.sol";
import "forge-std/console.sol";

contract DeployTradeExecutor is Script {
    // Default Uniswap V3 router for Sepolia testnet
    address constant DEFAULT_UNISWAP_V3_ROUTER = 0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        // Allow override of router address via environment variable
        address uniswapRouter;
        try vm.envAddress("UNISWAP_ROUTER") returns (address router) {
            uniswapRouter = router;
        } catch {
            uniswapRouter = DEFAULT_UNISWAP_V3_ROUTER;
        }
        
        console.log("Deploying TradeExecutor with Uniswap Router:", uniswapRouter);

        vm.startBroadcast(deployerPrivateKey);
        TradeExecutor tradeExec = new TradeExecutor(uniswapRouter);
        console.log("TradeExecutor deployed at:", address(tradeExec));
        vm.stopBroadcast();
    }
}