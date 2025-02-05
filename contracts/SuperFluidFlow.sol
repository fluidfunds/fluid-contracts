// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ISuperfluid, ISuperToken, ISuperApp, SuperAppDefinitions} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperfluidPool} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/ISuperfluidPool.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {CFASuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFASuperAppBase.sol";
import {IGeneralDistributionAgreementV1, ISuperfluidPool, PoolConfig} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/IPeripheryPayments.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import "./PureSuperToken.sol";
import {ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {IFluidFlowFactory} from "./IFluidFlowFactory.sol";

contract SuperFluidFlow is CFASuperAppBase {
    using SuperTokenV1Library for ISuperToken;
 
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

    struct Position {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
        uint256 timestamp;
        bool isOpen;
    }

    Position[] public positions;

    /// @notice Restricts function access to the contract owner.
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyFundManager() {
        require(msg.sender == fundManager, "Only fund manager can call this function");
        _;
    }

    modifier onlyWhitelisted(address tokenIn, address tokenOut) {
        require(IFluidFlowFactory(factory).isTokenWhitelisted(tokenIn), "TokenIn not whitelisted");
        require(IFluidFlowFactory(factory).isTokenWhitelisted(tokenOut), "TokenOut not whitelisted");
        _;
    }

    // --------------------
    // Event Declarations
    // --------------------
    event TradeExecuted(uint256 positionId, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);
    event UserLiquidated(address indexed user, uint256 tokenBalance, uint256 amountTaken);
    event PositionClosed(uint256 positionId);
    event FundClosed();

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
        require(_fundDuration > _subscriptionDuration, "Fund duration must be longer than subscription period");
        owner = msg.sender;
        acceptedToken = _acceptedToken;
        fundManager = _fundManager;
        
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
    }

    // Modifier to check time constraints
    modifier checkTimeConstraints() {
        require(block.timestamp <= fundEndTime, "Fund has ended");
        require(block.timestamp <= subscriptionDeadline, "Subscription period has ended");
        _;
    }

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
        require(block.timestamp <= subscriptionDeadline, "Subscription period has ended");

        int96 senderFlowRate = acceptedToken.getFlowRate(sender, address(this));
        
        // Start fund token stream to the sender
        fundToken.createFlow(sender, senderFlowRate);
        // No flow event emitted per your request
        
        return ctx;
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
        fundToken.updateFlow(sender, currentFlowRate, ctx);
        // No flow event emitted per your request
                
        return ctx;
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
        fundToken.deleteFlow(address(this), sender, ctx);
        // No flow event emitted per your request

        return ctx;
    }

    // Trading function
    function executeTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint24 poolFee
    ) external onlyFundManager onlyWhitelisted(tokenIn, tokenOut) {
        require(positions.length < MAX_POSITIONS, "Max positions reached");
        require(block.timestamp <= fundEndTime, "Trading period ended");

        // TODO: Downgrade from supepr usdc to usdc
        
        // Approve the router to spend tokenIn
        TransferHelper.safeApprove(tokenIn, UNISWAP_V3_ROUTER, amountIn);
        
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: poolFee,
            recipient: address(this),
            deadline: block.timestamp + 15 minutes,
            amountIn: amountIn,
            amountOutMinimum: minAmountOut,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOut = ISwapRouter(UNISWAP_V3_ROUTER).exactInputSingle(params);
        
        positions.push(Position({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            amountIn: amountIn,
            amountOut: amountOut,
            timestamp: block.timestamp,
            isOpen: true
        }));

        uint256 newPositionId = positions.length - 1;
        emit TradeExecuted(newPositionId, tokenIn, tokenOut, amountIn, amountOut);
    }

    // Function to close a position
    function closePosition(uint256 positionId) external onlyFundManager {
        require(positionId < positions.length, "Invalid position ID");

        // TODO: execute trade with uniswap from token -> usdc

        Position storage position = positions[positionId];
        require(position.isOpen, "Position already closed");
        
        // Implement logic to close the trade/position if needed.
        position.isOpen = false;
        emit PositionClosed(positionId);
    }

    function closeFund() external onlyFundManager {
        require(isFundActive, "Fund is not active");
        
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].isOpen) {
                require(false, "All positions should be closed");
            }
        }
        
        isFundActive = false;


        // TODO: calculate the amount of usdc in the contract and let fund manager take the profit sharing.

        if (totalStreamed < acceptedToken.balanceOf(address(this))) {
            // Send the % back to fund manager
        }

        emit FundClosed();
    }
}
