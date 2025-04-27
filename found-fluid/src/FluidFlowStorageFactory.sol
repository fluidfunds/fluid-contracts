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
    
    // Custom errors
    error FluidFlowFactory();
    error AlreadyInitialized();
    error InvalidFundAddress();
    error StorageAlreadyExists();
    
    // Array to keep track of all storage contracts
    address[] public allStorageContracts;
    
    // Mapping from fund address to its storage contract
    mapping(address => address) public fundToStorage;

    address public fluidFlowFactory;

    /**
     * @dev Initialize the contract with the fluid flow factory address
     * @notice This can only be called once by the owner
     * @param _fluidFlowFactory Address of the fluid flow factory
     */
    function initFluidFlowFactory(address _fluidFlowFactory) external onlyOwner {
        if (fluidFlowFactory != address(0)) revert AlreadyInitialized();
        fluidFlowFactory = _fluidFlowFactory;
    }
    
    /**
     * @notice Creates a new FluidFlowStorage contract for a fund
     * @param fundAddress The address of the fund that will use this storage
     * @param _fundEndTime When the fund will end
     * @return The address of the created storage contract
     */
    function createStorage(address fundAddress, uint256 _fundEndTime) external nonReentrant returns (address) {
        if (msg.sender != fluidFlowFactory) revert FluidFlowFactory();
        if (fundAddress == address(0)) revert InvalidFundAddress();
        if (fundToStorage[fundAddress] != address(0)) revert StorageAlreadyExists();
        
        // Create new storage contract
        FluidFlowStorage newStorage = new FluidFlowStorage();
        
        // Initialize storage with fund address
        newStorage.initialize(fundAddress, _fundEndTime);
        
        address storageAddress = address(newStorage);
        
        // Record the storage contract
        allStorageContracts.push(storageAddress);
        fundToStorage[fundAddress] = storageAddress;
        
        emit StorageCreated(storageAddress, fundAddress);
        return storageAddress;
    }
    
    /**
     * @dev Gets the total number of storage contracts created
     * @notice Returns the count of all storage contracts
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