// scripts/DeployPureSuperToken.s.sol
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {ISuperfluid, ISuperToken, ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {PureSuperTokenProxy} from "../src/PureSuperToken.sol";

contract DeployPureSuperToken is Script {
    function run() public {
        
        // Define deployment parameters
        string memory tokenName = "Dogecoin";
        string memory tokenSymbol = "DOGE";
        address receiver = 0x97A1F968762B1D12c394e62AAA480998518a3744; // Or specify another receiver address
        uint256 initialSupply = 1_000_000_000 * 1e18;
        
        // Superfluid host address - replace with the actual address for your network
        address hostAddress = vm.envAddress("SUPERFLUID_HOST"); // Replace with actual host address for your network
        
        vm.startBroadcast();
        
        // 1. Get SuperToken factory from host
        ISuperfluid host = ISuperfluid(hostAddress);
        ISuperTokenFactory factoryAddress = host.getSuperTokenFactory();
        ISuperTokenFactory factory = ISuperTokenFactory(factoryAddress);
        
        
        // 2. Deploy PureSuperTokenProxy
        PureSuperTokenProxy pureSuperToken = new PureSuperTokenProxy();
        
        // 3. Initialize the token
        pureSuperToken.initialize(
            factory,
            tokenSymbol,
            receiver,
            initialSupply
        );
        
        vm.stopBroadcast();
    }
}