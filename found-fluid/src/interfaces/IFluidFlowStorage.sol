// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ISuperfluid, ISuperToken} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";

/**
 * @title IFluidFlowStorage
 * @dev Interface for the FluidFlowStorage contract that manages all stored data for SuperfluidFlow
 */
interface IFluidFlowStorage {
    // Structs
    struct Trade {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 timestamp;
        bool isOpen;
    }
    
    // Events
    event UserLiquidated(address indexed user, uint256 tokenBalance, uint256 amountTaken);
    event PositionClosed(uint256 positionId);
    event FundClosed();
    event FundInitialized(
        ISuperToken acceptedToken, 
        address fundManager,
        uint256 fundDuration,
        uint256 subscriptionDuration,
        address factory
    );
    event UserWithdrawn(address indexed user, uint256 fundTokensRedeemed, uint256 amountReceived);
    event TradeExecuted(
        address indexed tokenIn, 
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 timestamp,
        bool isOpen
    );
    
    // View functions
    function owner() external view returns (address);
    function fundManager() external view returns (address);
    function factory() external view returns (address);
    function tradeExecutor() external view returns (address);
    function host() external view returns (ISuperfluid);
    function acceptedToken() external view returns (ISuperToken);
    function fundToken() external view returns (ISuperToken);
    function isFundActive() external view returns (bool);
    function totalStreamed() external view returns (uint256);
    function fundEndTime() external view returns (uint256);
    function subscriptionEndTime() external view returns (uint256);
    function fundClosedTimestamp() external view returns (uint256);
    function userDeposits(address user) external view returns (uint256);
    function userFlowRates(address user) external view returns (int96);
    function trades(uint256 index) external view returns (Trade memory);
    function getTradesCount() external view returns (uint256);
    
    // State changing functions
    function initialize(
        ISuperfluid _host,
        ISuperToken _acceptedToken,
        ISuperToken _fundToken,
        address _fundManager,
        uint256 _fundDuration,
        uint256 _subscriptionDuration,
        address _tradeExecutor
    ) external;
    
    function addTrade(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOut,
        bool _isOpen
    ) external;
    
    function setFundInactive() external;
    function updateUserFlowRate(address user, int96 flowRate) external;
    function incrementTotalStreamed(uint256 amount) external;
    function decrementTotalStreamed(uint256 amount) external;
    function updateUserDeposit(address user, uint256 amount) external;
} 