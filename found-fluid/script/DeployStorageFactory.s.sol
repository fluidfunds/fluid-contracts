// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {FluidFlowStorageFactory} from "../src/FluidFlowStorageFactory.sol";
import "forge-std/console.sol";

contract DeployStorageFactory is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the FluidFlowStorageFactory contract
        FluidFlowStorageFactory storageFactory = new FluidFlowStorageFactory();
        
        // Log the deployed addresses
        console.log("FluidFlowStorageFactory deployed at:", address(storageFactory));
        
        vm.stopBroadcast();
    }
}
