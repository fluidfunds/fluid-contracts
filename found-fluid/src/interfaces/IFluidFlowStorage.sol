// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ISuperfluid, ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

/**
 * @title IFluidFlowStorage
 * @dev Interface for the FluidFlowStorage contract that manages all stored data for SuperfluidFlow
 */
interface IFluidFlowStorage {
    // Structs
    struct UserFlow {
        uint256 startTimestamp;            // When the flow was created
        int96 flowRate;                   // Flow rate per second
        uint256 totalStreamedAmount;     // When the user updates the flowrate, we are storing the total streamed value here and changing the flowrate
        address userAddress;            // User's address
        ISuperToken token;              // Token being streamed
    }
    
    // Events
    event FundClosed();
    
    // View functions
    function userFlows(address user) external view returns (UserFlow memory);
    function fundAddress() external view returns (address);
    function fundClosedTime() external view returns (uint256);
    function isFundClosed() external view returns (bool);
    function fundEndTime() external view returns (uint256);
    function getTotalStreamed(address _user) external view returns (uint256);
    function isUserStreamActive(address userAddress) external view returns (bool);
    
    // State changing functions
    function initialize(address _fundAddress, uint256 _fundEndTime) external;
    
    function flowCreated(address _user, int96 _flowRate, ISuperToken _token) external;
    
    function flowUpdated(address _user, int96 _newFlowRate) external;
    
    function flowDeleted(address _user) external returns (uint256 excessAmount);
    
    function setFundClosedTime(uint256 _time) external;

    function isUserWithdrawn(address userAddress) external view returns (bool);
    
    function userWithdrawn(address userAddress) external;
}