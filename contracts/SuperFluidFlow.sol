// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ISuperfluid, ISuperToken, ISuperApp, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperfluidPool} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/ISuperfluidPool.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {CFASuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFASuperAppBase.sol";
import {IGeneralDistributionAgreementV1, ISuperfluidPool, PoolConfig} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";

contract SuperFluidFlow is CFASuperAppBase {
    using SuperTokenV1Library for ISuperToken;
    
    address public owner;
    ISuperToken acceptedToken;
    address public fundManager;
    ISuperToken public fundToken;

    // Add stream tracking variable
    uint256 public totalStreamed;

    // Add new timestamp variables
    uint256 public fundEndTime;
    uint256 public subscriptionDeadline;

    /// @notice Restricts function access to contract owner
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    constructor(
        ISuperToken _acceptedToken, 
        address _fundManager,
        uint256 _fundDuration,
        uint256 _subscriptionDuration,
        ISuperToken _fundToken
    ) CFASuperAppBase(
            ISuperfluid(ISuperToken(_acceptedToken).getHost())
        ) {
        require(_fundDuration > _subscriptionDuration, "Fund duration must be longer than subscription period");
        owner = msg.sender;
        acceptedToken = _acceptedToken;
        fundManager = _fundManager;
        fundToken = _fundToken;
        
        // Set the timestamps
        fundEndTime = block.timestamp + _fundDuration;
        subscriptionDeadline = block.timestamp + _subscriptionDuration;
    }

    // Add time validation modifier
    modifier checkTimeConstraints() {
        require(block.timestamp <= fundEndTime, "Fund has ended");
        require(block.timestamp <= subscriptionDeadline, "Subscription period has ended");
        _;
    }


     function isAcceptedSuperToken(ISuperToken superToken) public view override returns (bool) {
        return superToken == acceptedToken;
    }

    function liquidateUser() public {
        // transfer all the fundTokens from user to this contract
        uint256 fundTokenUserBalance = fundToken.balanceOf(msg.sender);

        fundToken.transferFrom(msg.sender, address(this), fundTokenUserBalance);

        uint256 proportion = (fundTokenUserBalance * 1e18) / totalStreamed;
        uint256 amountToTake = (proportion * fundTokenUserBalance) / 1e18;

        totalStreamed -= fundTokenUserBalance;

    }


    // ---------------------------------------------------------------------------------------------
    // SUPER APP CALLBACKS
    // ---------------------------------------------------------------------------------------------

    /*
     * @dev Callback function that gets executed when a new flow is created to this contract.
     *      
     * @param sender The address of the sender creating the flow.
     * @param ctx The context of the current flow transaction.
     * @return bytes Returns the new transaction context.
     */
    function onFlowCreated(
        ISuperToken /*superToken*/,
        address sender,
        bytes calldata ctx
    ) internal override returns (bytes memory newCtx) {
        require(block.timestamp <= subscriptionDeadline, "Subscription period has ended");

        int96 senderFlowRate = acceptedToken.getFlowRate(sender, address(this));
        
        // Start fund token stream to the sender
        fundToken.createFlow(sender, senderFlowRate);
        

        return ctx;
    }

    /*
     * @dev Callback function that gets executed when an existing flow to this contract is updated.
     * 
     * @param sender The address of the sender updating the flow.
     * @param previousflowRate The previous flow rate before the update.
     * @param lastUpdated The timestamp of the last update.
     * @param ctx The context of the current flow transaction.
     * @return bytes Returns the new transaction context.
     */
    function onFlowUpdated(
        ISuperToken,
        address sender,
        int96 previousflowRate,
        uint256 lastUpdated,
        bytes calldata ctx
    ) internal override returns (bytes memory newCtx) {
        // Calculate accumulated amount since last update
        uint256 timeElapsed = block.timestamp - lastUpdated;
        totalStreamed += uint256(uint96(previousflowRate)) * timeElapsed;

        int96 currentFlowRate = acceptedToken.getFlowRate(sender, address(this));
        
        // Update fund token stream to the sender
        fundToken.updateFlow(sender, currentFlowRate);
                
        return ctx;
    }

    /*
     * @dev Callback function that gets executed when a flow to this contract is deleted.
     *      
     * @param sender The address of the sender deleting the flow.
     * @param ctx The context of the current flow transaction.
     * @return bytes Returns the new transaction context.
     */

    function onFlowDeleted(
        ISuperToken /*superToken*/,
        address sender,
        address /*receiver*/,
        int96 previousFlowRate,
        uint256 lastUpdated,
        bytes calldata ctx
    ) internal override returns (bytes memory newCtx) {
        // Add final accumulated amount from last update
        uint256 timeElapsed = block.timestamp - lastUpdated;
        totalStreamed += uint256(uint96(previousFlowRate)) * timeElapsed;

        // Delete fund token stream to the sender
        fundToken.deleteFlow(address(this), sender);

        return ctx;
    }


}
