// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import {ISuperfluid, ISuperToken, ISuperApp, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperfluidPool} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/ISuperfluidPool.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {CFASuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFASuperAppBase.sol";
import {IGeneralDistributionAgreementV1, ISuperfluidPool, PoolConfig} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";

import "./PureSuperToken.sol";
import {ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IFluidFlowFactory} from "./IFluidFlowFactory.sol";
import "./TradeExecutor.sol";

contract SuperFluidFlow is CFASuperAppBase {
    using SuperTokenV1Library for ISuperToken;

    // Custom Errors
    error OnlyOwner();
    error OnlyFundManager();
    error TokenInNotWhitelisted(address tokenIn);
    error TokenOutNotWhitelisted(address tokenOut);
    error FundDurationTooShort();
    error SubscriptionPeriodEnded();
    error MaxPositionsReached();
    error TradingPeriodEnded();
    error InvalidPositionId();
    error PositionAlreadyClosed();
    error FundNotActive();
    error OpenPositionsExist();
 
    address public owner;
    ISuperToken acceptedToken;
    address public fundManager;
    ISuperToken public fundToken;

    uint256 public totalStreamed;

    bool public isFundActive;

    // Timestamp variables
    uint256 public fundEndTime;
    uint256 public subscriptionDeadline;

    address public constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    uint8 public constant MAX_POSITIONS = 10;

    address public factory;
    address public tradeExecutor;

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

    // modifier onlyWhitelisted(address tokenIn, address tokenOut) {
    //     if (!IFluidFlowFactory(factory).isTokenWhitelisted(tokenIn)) revert TokenInNotWhitelisted(tokenIn);
    //     if (!IFluidFlowFactory(factory).isTokenWhitelisted(tokenOut)) revert TokenOutNotWhitelisted(tokenOut);
    //     _;
    // }

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
        string _fundTokenName,
        string _fundTokenSymbol);

    constructor(
        ISuperToken _acceptedToken, 
        address _fundManager,
        uint256 _fundDuration,
        uint256 _subscriptionDuration,
        address _factory,
        string memory _fundTokenName,
        string memory _fundTokenSymbol
    ) CFASuperAppBase(
            ISuperfluid(ISuperToken(_acceptedToken).getHost())
        ) {
        if (_fundDuration <= _subscriptionDuration) revert FundDurationTooShort();
        owner = msg.sender;
        acceptedToken = _acceptedToken;
        fundManager = _fundManager;
        
        // TODO: pass the endtime instead of calculating
        fundEndTime = block.timestamp + _fundDuration;
        subscriptionDeadline = block.timestamp + _subscriptionDuration;
        factory = _factory;
    
        isFundActive = true;

        // Deploy new PureSuperTokenProxy
        PureSuperTokenProxy tokenProxy = new PureSuperTokenProxy();
        
        // Get SuperToken factory from host
        ISuperfluid host = ISuperfluid(ISuperToken(_acceptedToken).getHost());
        ISuperTokenFactory superTokenFactory = ISuperTokenFactory(host.getSuperTokenFactory());
        
        // Initialize the token with 1 billion units (assuming 18 decimals)
        uint256 initialSupply = 1_000_000_000 * 1e18;
        tokenProxy.initialize(
            superTokenFactory,
            _fundTokenName,
            _fundTokenSymbol,
            address(this), // token receiver
            initialSupply
        );
        
        // Set the fund token
        fundToken = ISuperToken(address(tokenProxy));

        emit FundFlow(_acceptedToken, 
         _fundManager,
        _fundDuration,
        _subscriptionDuration,
         _factory,
         _fundTokenName,
        _fundTokenSymbol);
    }

    // Modifier to check time constraints
    // modifier checkTimeConstraints() {
    //     if (block.timestamp > fundEndTime) revert TradingPeriodEnded();
    //     if (block.timestamp > subscriptionDeadline) revert SubscriptionPeriodEnded();
    //     _;
    // }

    function isAcceptedSuperToken(ISuperToken superToken) public view override returns (bool) {
        return superToken == acceptedToken;
    }

    function liquidateUser() public {
        uint256 fundTokenUserBalance = fundToken.balanceOf(msg.sender);

        fundToken.transferFrom(msg.sender, address(this), fundTokenUserBalance);

        uint256 proportion = (fundTokenUserBalance * 1e18) / totalStreamed;
        uint256 amountToTake = (proportion * fundTokenUserBalance) / 1e18;

        totalStreamed -= fundTokenUserBalance;

        emit UserLiquidated(msg.sender, fundTokenUserBalance, amountToTake);

        // TODO: Think of a way to give the positions back to the user if the user is liquidating before the end date.
    }

    function changeFundTokenAdd(ISuperToken _add) external {
        fundToken = _add;
    }

    // TODO: only for test, change afterwards
    // function changeAcceptedSuperToken(ISuperToken _token) public {
    //     acceptedToken = _token;
    // }

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
        ISuperToken /*superToken*/,
        address sender,
        bytes calldata ctx
    ) internal override returns (bytes memory newCtx) {
        if (block.timestamp > subscriptionDeadline) revert SubscriptionPeriodEnded();

        int96 senderFlowRate = acceptedToken.getFlowRate(sender, address(this));
        
        // Start fund token stream to the sender
        fundToken.createFlow(sender, senderFlowRate);
        // No flow event emitted per your request

        newCtx = ctx;
    }

    function testStartStream(int96 flowRate) external {
        fundToken.createFlow(msg.sender, flowRate);
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
        ISuperToken,
        address sender,
        int96 previousflowRate,
        uint256 lastUpdated,
        bytes calldata ctx
    ) internal override returns (bytes memory newCtx) {
        uint256 timeElapsed = block.timestamp - lastUpdated;
        totalStreamed += uint256(uint96(previousflowRate)) * timeElapsed;

        int96 currentFlowRate = acceptedToken.getFlowRate(sender, address(this));
        
        // Update fund token stream to the sender
        newCtx = fundToken.updateFlowWithCtx(sender, currentFlowRate, ctx);
        // No flow event emitted per your request
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
        int96 previousFlowRate,
        uint256 lastUpdated,
        bytes calldata ctx
    ) internal override returns (bytes memory newCtx) {
        uint256 timeElapsed = block.timestamp - lastUpdated;
        totalStreamed += uint256(uint96(previousFlowRate)) * timeElapsed;

        // Delete fund token stream to the sender
        newCtx = fundToken.deleteFlowWithCtx(address(this), sender, ctx);
        // No flow event emitted per your request
    }

    // Trading function
    function executeTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint24 poolFee
    ) external onlyFundManager {
        if (block.timestamp > fundEndTime) revert TradingPeriodEnded();
        
        require(tradeExecutor != address(0), "Trade executor not set");

        uint256 amountOut = TradeExecutor(tradeExecutor).executeSwap(
            tokenIn,
            tokenOut,
            amountIn,
            minAmountOut,
            poolFee,
            address(this)
        );
        
        // Emit event with all trade details instead of storing
        emit TradeExecuted(
            tokenIn,
            tokenOut,
            amountIn,
            amountOut,
            block.timestamp,
            true  // isOpen flag
        );
    }

    // function closeFund() external onlyFundManager {
    //     if (!isFundActive) revert FundNotActive();
        
    //     // TODO: check the amount of usdc available in contract
        
    //     isFundActive = false;

    //     // TODO: calculate the amount of usdc in the contract and let fund manager take the profit sharing.
    //     // 100 usdc
    //     // 110 usdc -> profit
    //     // 10 -> 1 -> fund manager

    //     if (totalStreamed < acceptedToken.balanceOf(address(this))) {
    //         // Send the % back to fund manager
    //     }

    //     emit FundClosed();
    // }

    // funciton claimLiquidation() {
    //     // fundToken 
    // }

    function setTradeExecutor(address _tradeExecutor) external onlyOwner {
        tradeExecutor = _tradeExecutor;
    }
}
