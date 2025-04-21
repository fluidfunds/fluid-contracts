// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./FluidFlowStorage.sol";

/**
 * @title FluidFlowStorageFactory
 * @dev Factory contract for creating FluidFlowStorage instances
 */
contract FluidFlowStorageFactory is Ownable, ReentrancyGuard {
    // Events
    event StorageCreated(address indexed storageAddress, address indexed fundAddress);
    
    // Array to keep track of all storage contracts
    address[] public allStorageContracts;
    
    // Mapping from fund address to its storage contract
    mapping(address => address) public fundToStorage;
    
    /**
     * @notice Creates a new FluidFlowStorage contract for a fund
     * @param fundAddress The address of the fund that will use this storage
     * @return The address of the created storage contract
     */
    function createStorage(address fundAddress) external nonReentrant returns (address) {
        require(fundAddress != address(0), "Invalid fund address");
        require(fundToStorage[fundAddress] == address(0), "Storage already exists for this fund");
        
        // Create new storage contract
        FluidFlowStorage newStorage = new FluidFlowStorage();
        
        // Initialize storage with fund address
        newStorage.initialize(fundAddress);
        
        address storageAddress = address(newStorage);
        
        // Record the storage contract
        allStorageContracts.push(storageAddress);
        fundToStorage[fundAddress] = storageAddress;
        
        emit StorageCreated(storageAddress, fundAddress);
        return storageAddress;
    }
    
    /**
     * @notice Gets the total number of storage contracts created
     * @return The number of storage contracts
     */
    function getStorageCount() external view returns (uint256) {
        return allStorageContracts.length;
    }
    
    /**
     * @notice Gets the storage contract address for a specific fund
     * @param fundAddress The fund address to look up
     * @return The storage contract address for the fund
     */
    function getStorageForFund(address fundAddress) external view returns (address) {
        return fundToStorage[fundAddress];
    }
} 