// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {FluidFlowFactory} from "../src/FluidFlowFactory.sol";
import {FluidFlowStorageFactory} from "../src/FluidFlowStorageFactory.sol";
import {ISuperfluid} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {console} from "forge-std/console.sol";
import {IFluidFlowStorageFactory} from "../src/interfaces/IFluidFlowStorageFactory.sol";

contract DeployFluidFlowFactory is Script {
    // For Sepolia testnet - replace with appropriate addresses for other networks
    ISuperfluid host = ISuperfluid(0x109412E3C84f0539b43d39dB691B08c90f58dC7c);
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address tradeExecutorAddress = vm.envAddress("TRADE_EXECUTOR_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy the FluidFlowStorageFactory
        FluidFlowStorageFactory storageFactory = new FluidFlowStorageFactory();
        console.log("FluidFlowStorageFactory deployed at:", address(storageFactory));
        
        // 2. Deploy the FluidFlowFactory
        FluidFlowFactory factory = new FluidFlowFactory(
            tradeExecutorAddress,
            IFluidFlowStorageFactory(address(storageFactory))
        );
        console.log("FluidFlowFactory deployed at:", address(factory));
        
        // 3. Initialize the storage factory with the factory address
        storageFactory.initFluidFlowFactory(address(factory));
        console.log("StorageFactory initialized with factory address");
        
        vm.stopBroadcast();
    }
}