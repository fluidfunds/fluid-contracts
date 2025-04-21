// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/**
 * @title IFluidFlowStorageFactory
 * @dev Interface for FluidFlowStorageFactory to abstract storage creation
 */
interface IFluidFlowStorageFactory {
    /**
     * @notice Creates a new FluidFlowStorage contract for a fund
     * @param fundAddress The address of the fund
     * @return The address of the created storage contract
     */
    function createStorage(address fundAddress) external returns (address);

    /**
     * @notice Returns total number of storage contracts created
     * @return count of storage contracts
     */
    function getStorageCount() external view returns (uint256);

    /**
     * @notice Returns storage contract for a given fund
     * @param fundAddress The fund address to look up
     * @return storage contract address
     */
    function getStorageForFund(address fundAddress) external view returns (address);
}
