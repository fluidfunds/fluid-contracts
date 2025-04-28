// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {SuperFluidFlow} from "../src/SuperFluidFlow.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";
contract FundInteraction is Script {
    function executeTrade() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address fundAddress = vm.envAddress("FUND_ADDRESS");
        address tokenIn = vm.envAddress("TOKEN_IN");
        address tokenOut = vm.envAddress("TOKEN_OUT");
        uint256 amountIn = vm.envUint("AMOUNT_IN");
        uint256 minAmountOut = vm.envUint("MIN_AMOUNT_OUT");
        uint24 poolFee = uint24(vm.envUint("POOL_FEE"));
        
        console.log("Executing trade with the following parameters:");
        console.log("  Fund Address:", fundAddress);
        console.log("  Token In:", tokenIn);
        console.log("  Token Out:", tokenOut);
        console.log("  Amount In:", amountIn);
        console.log("  Minimum Amount Out:", minAmountOut);
        console.log("  Pool Fee:", poolFee);
        
        vm.startBroadcast(deployerPrivateKey);
        SuperFluidFlow fund = SuperFluidFlow(fundAddress);
        fund.executeTrade(
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            poolFee
        );
        console.log("Trade executed successfully");
        vm.stopBroadcast();
    }
    
    function closeFund() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address fundAddress = vm.envAddress("FUND_ADDRESS");
        
        console.log("Closing fund at address:", fundAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        SuperFluidFlow fund = SuperFluidFlow(fundAddress);
        fund.closeFund();
        console.log("Fund closed successfully");
        vm.stopBroadcast();
    }
    
    function withdraw() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address fundAddress = vm.envAddress("FUND_ADDRESS");
        
        console.log("Withdrawing from fund at address:", fundAddress);
        
        vm.startBroadcast(deployerPrivateKey);
        SuperFluidFlow fund = SuperFluidFlow(fundAddress);
        fund.withdraw();
        console.log("Withdrawal completed successfully");
        vm.stopBroadcast();
    }
}
