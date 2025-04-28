// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {FluidFlowFactory} from "../src/FluidFlowFactory.sol";
import {ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperToken.sol";
import {console} from "forge-std/console.sol";

contract CreateFund is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        ISuperToken acceptedToken = ISuperToken(vm.envAddress("ACCEPTED_TOKEN"));
        
        // Fund parameters can be configured through environment variables
        string memory fundName = vm.envOr("FUND_NAME", string("AlphaFund"));
        uint256 managerFee = vm.envOr("MANAGER_FEE", uint256(1000)); // Default 10% (1000 basis points)
        uint256 fundDuration = vm.envOr("FUND_DURATION", uint256(30 days));
        uint256 subscriptionPeriod = vm.envOr("SUBSCRIPTION_PERIOD", uint256(7 days));
        
        console.log("Creating fund with the following parameters:");
        console.log("  Factory Address:", factoryAddress);
        console.log("  Fund Name:", fundName);
        console.log("  Manager Fee:", managerFee, "basis points");
        console.log("  Fund Duration:", fundDuration, "seconds");
        console.log("  Subscription Period:", subscriptionPeriod, "seconds");
        console.log("  Accepted Token:", address(acceptedToken));
        
        vm.startBroadcast(deployerPrivateKey);
        address fundAddress = FluidFlowFactory(factoryAddress).createFund(
            fundName,
            managerFee,
            block.timestamp + subscriptionPeriod,
            fundDuration,
            acceptedToken
        );
        console.log("Fund created successfully at address:", fundAddress);
        vm.stopBroadcast();
    }
}