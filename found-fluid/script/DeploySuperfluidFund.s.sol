// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {SuperFluidFlow} from "../src/SuperFluidFlow.sol";
import {ISuperfluid} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import {IFluidFlowStorage} from "../src/interfaces/IFluidFlowStorage.sol";
import "forge-std/console.sol";

contract DeploySuperFluidFlow is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address hostAddress = vm.envAddress("SUPERFLUID_HOST");
        ISuperfluid host = ISuperfluid(hostAddress);
        ISuperToken acceptedToken = ISuperToken(vm.envAddress("ACCEPTED_TOKEN"));
        address fundManager = vm.envAddress("FUND_MANAGER");

        string memory fundTokenSymbol = vm.envOr("FUND_TOKEN_SYMBOL", string("FF"));
        address tradeExecutor = vm.envAddress("TRADE_EXECUTOR_ADDRESS");
        IFluidFlowStorage fundStorage = IFluidFlowStorage(vm.envAddress("FUND_STORAGE_ADDRESS"));

        console.log("Deploying SuperFluidFlow with parameters:");
        console.log("  Host:", hostAddress);
        console.log("  AcceptedToken:", address(acceptedToken));
        console.log("  FundManager:", fundManager);
        console.log("  FundTokenSymbol:", fundTokenSymbol);
        console.log("  TradeExecutor:", tradeExecutor);
        console.log("  FundStorage:", address(fundStorage));
        
        vm.startBroadcast(deployerPrivateKey);
        SuperFluidFlow fund = new SuperFluidFlow(host);
        // fund.initialize(
        //     acceptedToken,
        //     fundManager,
        //     20 days,
        //     5 days,
        //     address(0x408Df7518640F02CB7650ae265fec4EAE60f1168), // factory address not used for direct deployment
        //     fundTokenSymbol,
        //     tradeExecutor,
        //     fundStorage
        // );
        console.log("SuperFluidFlow deployed at:", address(fund));
        vm.stopBroadcast();
    }
}
