// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import {ISuperfluid, ISuperToken, ISuperApp, SuperAppDefinitions, ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperfluidPool} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/ISuperfluidPool.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {CFASuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFASuperAppBase.sol";
import {IGeneralDistributionAgreementV1, ISuperfluidPool, PoolConfig} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./PureSuperToken.sol";
import "./interfaces/ITradeExecutor.sol";
import "./interfaces/IFluidFlowStorage.sol";

contract SuperFluidFlow is CFASuperAppBase {
    using SuperTokenV1Library for ISuperToken;

    // Custom Errors
    error OnlyOwner();
    error OnlyFundManager();
    error FundDurationTooShort();
    error SubscriptionPeriodEnded();
    // error TradingPeriodEnded();
    error FundStillActive();
    error UserStreamActive();
    error FluidFlowFactory();
 
    address public owner;
    ISuperToken public acceptedToken;
    address public fundManager;
    ISuperToken public fundToken;
    IFluidFlowStorage public fundStorage;

    uint256 public totalStreamed;
    uint256 public totalFundTokensUsed;

    uint256 public totalUsdcBalanceFundClosed;

    bool public isFundActive;

    // Timestamp variables
    uint256 public fundEndTime;
    uint256 public subscriptionEndTime;

    address public factory;
    address public tradeExecutor;
    ISuperfluid public host;

    uint256 public fundClosedTimestamp;

    // Update event to include all relevant trade data
    event TradeExecuted(
        address indexed tokenIn, 
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 timestamp,
        bool isOpen
    );

    /// @notice Restricts function access to the contract owner.
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier onlyFundManager() {
        if (msg.sender != fundManager) revert OnlyFundManager();
        _;
    }

    // --------------------
    // Event Declarations
    // --------------------
    event UserLiquidated(address indexed user, uint256 tokenBalance, uint256 amountTaken);
    event PositionClosed(uint256 positionId);
    event FundClosed();

    event FundFlow(ISuperToken _acceptedToken, 
        address _fundManager,
        uint256 _fundDuration,
        uint256 _subscriptionDuration,
        address _factory,
        string _fundTokenSymbol);

    event UserWithdrawn(address indexed user, uint256 fundTokensRedeemed, uint256 amountReceived);

    /**
     * @dev Initialize the contract with the SuperFluid host
     * @notice This can only be called once during deployment
     * @param _host Address of the SuperFluid host
     */
    constructor(ISuperfluid _host) CFASuperAppBase(_host) {
        owner = msg.sender;
        host = _host;

        _host.registerApp(getConfigWord(true, true, true));
    }

    /**
     * @dev Initialize the contract with fund parameters
     * @notice This can only be called once after deployment
     * @param _acceptedToken The SuperToken accepted for deposits
     * @param _fundManager Address of the fund manager
     * @param _fundDuration Duration of the fund in seconds
     * @param _subscriptionDuration Duration of the subscription period in seconds
     * @param _factory Address of the factory that created this fund
     * @param _fundTokenSymbol Symbol of the fund token
     * @param _tradeExec Address of the trade executor
     * @param _fundStorage Address of the fund storage contract
     */
    function initialize(
        ISuperToken _acceptedToken, 
        address _fundManager,
        uint256 _fundDuration,
        uint256 _subscriptionDuration,
        address _factory,
        string memory _fundTokenSymbol,
        address _tradeExec,
        IFluidFlowStorage _fundStorage
    ) external {
        if (msg.sender != _factory) revert FluidFlowFactory();
        if (_fundDuration <= _subscriptionDuration) revert FundDurationTooShort();
        
        acceptedToken = _acceptedToken;
        fundManager = _fundManager;
        tradeExecutor = _tradeExec;
        fundStorage = _fundStorage;
        
        // Calculate end times
        subscriptionEndTime = block.timestamp + _subscriptionDuration;
        fundEndTime = block.timestamp + _fundDuration;
        
        // Initialize state variables
        factory = _factory;
        isFundActive = true;
        
        // Create a pure super token for fund shares
        PureSuperTokenProxy tokenProxy = new PureSuperTokenProxy();
        
        // Get SuperToken factory from host
        ISuperTokenFactory superTokenFactory = ISuperTokenFactory(host.getSuperTokenFactory());
        
        tokenProxy.initialize(
            superTokenFactory,
            _fundTokenSymbol,
            address(this), // Fund contract owns the tokens initially
            1_000_000_000 * 1e18 // 1 billion tokens
        );
        
        fundToken = ISuperToken(address(tokenProxy));

        emit FundFlow(
            _acceptedToken,
            _fundManager,
            _fundDuration,
            _subscriptionDuration,
            _factory,
            _fundTokenSymbol
        );
    }



    /**
     * @dev Checks if a token is the accepted SuperToken for this fund
     * @notice Implements the CFASuperAppBase interface
     * @param superToken The token to check
     * @return True if the token is the accepted token, false otherwise
     */
    function isAcceptedSuperToken(ISuperToken superToken) public view override returns (bool) {
        return superToken == acceptedToken;
    }

    // ---------------------------------------------------------------------------------------------
    // SUPER APP CALLBACKS
    // ---------------------------------------------------------------------------------------------

    /*
     * @dev Callback executed when a new flow is created to this contract.
     *      The fund token stream is created for the sender.
     * @param sender The sender of the flow.
     * @param ctx The context.
     * @return bytes Returns the transaction context.
     */
    function onFlowCreated(
        ISuperToken ,//superToken,
        address sender,
        bytes calldata ctx
    ) internal override returns (bytes memory newCtx) {
        int96 senderFlowRate = acceptedToken.getFlowRate(sender, address(this));
        
        if (block.timestamp > subscriptionEndTime) {
            newCtx = acceptedToken.createFlowWithCtx(sender, senderFlowRate, ctx);
            return newCtx;
        }

        newCtx = ctx;

        newCtx = fundToken.createFlowWithCtx(sender, senderFlowRate, ctx);

        fundStorage.flowCreated(sender, senderFlowRate, acceptedToken);

        return newCtx;
    }

    /*
     * @dev Callback executed when an existing flow is updated.
     *      The accumulated amount is updated and the fund token stream is updated.
     * @param sender The sender updating the flow.
     * @param previousflowRate The previous flow rate.
     * @param lastUpdated Timestamp of the last update.
     * @param ctx The transaction context.
     * @return bytes Returns the updated context.
     */
    function onFlowUpdated(
        ISuperToken /*superToken*/,
        address sender,
        int96 /*previousflowRate*/,
        uint256 /*lastUpdated*/,
        bytes calldata ctx
    ) internal override returns (bytes memory newCtx) {      
        int96 currentFlowRate = acceptedToken.getFlowRate(sender, address(this));  
        fundStorage.flowUpdated(sender, currentFlowRate);

        // Update fund token stream to the sender
        newCtx = fundToken.updateFlowWithCtx(sender, currentFlowRate, ctx);
        // No flow event emitted per your request
        return newCtx;

    }

    /*
     * @dev Callback executed when a flow to this contract is deleted.
     *      The final accumulated amount is added and the fund token stream is deleted.
     * @param sender The sender deleting the flow.
     * @param ctx The transaction context.
     * @return bytes Returns the updated context.
     */
    function onFlowDeleted(
        ISuperToken /*superToken*/,
        address sender,
        address /*receiver*/,
        int96 /* previousFlowRate */,
        uint256 /* lastUpdated */,
        bytes calldata ctx
    ) internal override returns (bytes memory newCtx) {

        // Get excess amount from storage contract that should be returned to the user
        uint256 excessStreamedAmount = fundStorage.flowDeleted(sender);

        // Delete fund token stream to the sender
        newCtx = fundToken.deleteFlowWithCtx(address(this), sender, ctx);

        if (excessStreamedAmount > 0) {
            acceptedToken.transfer(sender, excessStreamedAmount);
        }

        return newCtx;

    }


    /**
     * @dev Executes a trade through the trade executor
     * @notice Can only be called by the fund manager
     * @param tokenIn Address of the token to sell
     * @param tokenOut Address of the token to buy
     * @param amountIn Amount of input token to swap
     * @param minAmountOut Minimum amount of output tokens expected
     * @param poolFee Fee tier of the pool to use for the swap
     */
    function executeTrade(
        address tokenIn,
        address tokenOut, 
        uint256 amountIn,
        uint256 minAmountOut, 
        uint24 poolFee 
    ) external onlyFundManager {

        acceptedToken.downgrade(acceptedToken.balanceOf(address(this)));

        IERC20(tokenIn).approve(address(tradeExecutor), amountIn);

        uint256 amountOut = ITradeExecutor(tradeExecutor).executeSwap(
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            poolFee
        );
        
        // Emit event with all trade details instead of storing
        emit TradeExecuted(
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            block.timestamp,
            true
        );
    }

    /**
     * @dev Closes the fund and distributes manager profits
     * @notice Can only be called by the fund manager
     */
    function closeFund() public {
        if (block.timestamp < fundEndTime) {
            if (msg.sender != fundManager) revert OnlyFundManager();
        }
        IERC20 underlayingAcceptedToken = IERC20(acceptedToken.getUnderlyingToken());
        uint256 balance = underlayingAcceptedToken.balanceOf(address(this));
        underlayingAcceptedToken.approve(address(acceptedToken), balance);

        acceptedToken.upgrade(balance);

        if (isFundActive){
            uint256 currentBalance = acceptedToken.balanceOf(address(this));
            totalFundTokensUsed = (1_000_000_000 * 1e18) - fundToken.balanceOf(address(this));

            // Calculate profit (if any)
            if (currentBalance > totalFundTokensUsed) {
                uint256 profitInUSD = currentBalance - totalFundTokensUsed;
                // Fund manager gets 10% of profits (1000 basis points)
                uint256 managerShare = (profitInUSD * 1000) / 10000;
                
                // Transfer manager's share
                acceptedToken.transfer(fundManager, managerShare);
            }

            totalUsdcBalanceFundClosed = acceptedToken.balanceOf(address(this));

            isFundActive = false;

            fundClosedTimestamp = block.timestamp;

            emit FundClosed();
        }
    
    }


    /**
     * @dev Allows users to withdraw their proportional share after fund closure
     * @notice Can only be called after the fund is closed
     */
    function withdraw() external {
        if (isFundActive) revert FundStillActive();

        // check user stream should not be running
        if (fundStorage.isUserStreamActive(msg.sender)) revert UserStreamActive();

        // check user has not withdrawn
        if (fundStorage.isUserWithdrawn(msg.sender)) revert UserAlreadyWithdrawn();

        uint256 userTotalStreamed = fundStorage.getTotalStreamed(msg.sender);

        // Calculate user's proportional share of the total assets
        uint256 userShare = (userTotalStreamed * totalUsdcBalanceFundClosed *1000) / (totalFundTokensUsed * 1000);

        // Transfer the proportional share of accepted tokens to the user
        acceptedToken.transfer(msg.sender, userShare);

        // Mark user as withdrawn
        fundStorage.userWithdrawn(msg.sender);

        emit UserWithdrawn(msg.sender, userTotalStreamed, userShare);
    }


    error UserAlreadyWithdrawn();
}
