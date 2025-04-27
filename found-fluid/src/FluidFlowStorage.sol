// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ISuperfluid, ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

/**
 * @title FluidFlowStorage
 * @dev Storage contract for SuperfluidFlow that manages all stored data
 */
contract FluidFlowStorage {
    
    struct UserFlow {
        uint256 startTimestamp;            // When the flow was created
        int96 flowRate;                   // Flow rate per second
        uint256 totalStreamedAmount;     // When the user updates the flowrate, we are storing the total streamed value here and chnaging the flowrate
        address userAddress;            // User's address
        ISuperToken token;              // Token being streamed
        bool userWithdrawn;             // Whether the user has withdrawn their funds
    }

    // Mapping from user address to their flow data
    mapping(address => UserFlow) public userFlows;

    // Fund address that receives flows
    address public fundAddress;

    // fund closed timestamp
    uint256 public fundClosedTime; // when the fund was closed, this can be 0 if the fund is still active

    // is fund closed
    bool public isFundClosed; // true when the fund is closed

    uint256 public fundEndTime; // when the fund will end
    
    /**
     * @dev Modifier to restrict function access to only the fund address
     */
    modifier onlyFund() {
        require(msg.sender == fundAddress, "Only fund can call this function");
        _;
    }
    
    /**
     * @dev Initialize the contract with the fund address
     * @notice This can only be called once during deployment
     * @param _fundAddress Address of the fund
     * @param _fundEndTime When the fund will end
     */ 
    function initialize(address _fundAddress, uint256 _fundEndTime) external {
        require(fundAddress == address(0), "Already initialized");
        require(_fundAddress != address(0), "Invalid fund address");
        fundAddress = _fundAddress;
        isFundClosed = false;
        fundEndTime = _fundEndTime;
    }

    /**
     * @dev Called when a user creates a new flow
     * @notice This can only be called by the fund address
     * @param _user User address
     * @param _flowRate Flow rate per second
     * @param _token Super token being streamed
     */
    function flowCreated(address _user, int96 _flowRate, ISuperToken _token) external onlyFund {
        userFlows[_user] = UserFlow({
            startTimestamp: block.timestamp,
            flowRate: _flowRate,
            totalStreamedAmount: 0,
            userAddress: _user,
            token: _token,
            userWithdrawn: false
        });
    }
    
    /**
     * @dev Called when a user updates an existing flow
     * @notice This can only be called by the fund address
     * @param _user User address
     * @param _newFlowRate New flow rate per second
     */
    function flowUpdated(address _user, int96 _newFlowRate) external onlyFund {
        UserFlow storage flow = userFlows[_user];
        
        // Calculate streamed amount until now and store it
        uint256 timeElapsed = block.timestamp - flow.startTimestamp;
        uint256 amountStreamed = uint256(int256(flow.flowRate)) * timeElapsed;
        
        // Update the flow info
        flow.totalStreamedAmount += amountStreamed;
        flow.flowRate = _newFlowRate;
        flow.startTimestamp = block.timestamp;
    }
    
    /**
     * @dev Called when a user's flow is deleted/stopped
     * @param _user User address
     */
    function flowDeleted(address _user) external onlyFund returns (uint256 excessAmount) {
        UserFlow storage flow = userFlows[_user];
        uint256 timeElapsed;

        if (isFundClosed) {
            timeElapsed = fundClosedTime - flow.startTimestamp;
            uint256 amountUsed = uint256(int256(flow.flowRate)) * timeElapsed;
            flow.totalStreamedAmount += amountUsed;
            flow.flowRate = 0;

            uint256 totalAmount = (block.timestamp - flow.startTimestamp) * uint256(int256(flow.flowRate));
            
            excessAmount = totalAmount - amountUsed;
            
        } else {
            timeElapsed = block.timestamp - flow.startTimestamp;
            excessAmount = 0;

            uint256 amountStreamed = uint256(int256(flow.flowRate)) * timeElapsed;
            
            flow.totalStreamedAmount += amountStreamed;
            flow.flowRate = 0;
        }

        return excessAmount;

    }

    /**
     * @dev Get the total amount streamed by a user
     * @param _user User address
     * @return Total amount streamed
     */
    function getTotalStreamed(address _user) external view returns (uint256) {
        UserFlow memory flow = userFlows[_user];
        
        if (flow.startTimestamp == 0) {
            return 0;
        }
        
        if (flow.flowRate == 0) {
            return flow.totalStreamedAmount;
        }
        
        uint256 timeElapsed = block.timestamp - flow.startTimestamp;
        uint256 currentStreamed = uint256(int256(flow.flowRate)) * timeElapsed;
        
        return flow.totalStreamedAmount + currentStreamed;
    }

    /**
     * @dev Sets the fund closed timestamp, can only be called once by fund address
     * @param _time Timestamp when the fund was closed
     */
    function setFundClosedTime(uint256 _time) external onlyFund {
        require(fundClosedTime == 0, "Fund close time already set");
        fundClosedTime = _time;
        isFundClosed = true;
        emit FundClosed();
    }

    function isUserStreamActive(address userAddress) external view returns (bool) {
        return userFlows[userAddress].flowRate != 0;
    }

    function userWithdrawn(address userAddress) external onlyFund {
        // check user withdrawn true so that we dont allow multiple withdrawals
        userFlows[userAddress].userWithdrawn = true;
    }  

    function isUserWithdrawn(address userAddress) external view returns (bool) {
        return userFlows[userAddress].userWithdrawn;
    }   

    event FundClosed();
}
