// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;


import {ISuperfluid, ISuperToken, ISuperApp, SuperAppDefinitions, ISuperTokenFactory} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import {ISuperfluidPool} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/ISuperfluidPool.sol";
import {SuperTokenV1Library} from "@superfluid-finance/ethereum-contracts/contracts/apps/SuperTokenV1Library.sol";
import {CFASuperAppBase} from "@superfluid-finance/ethereum-contracts/contracts/apps/CFASuperAppBase.sol";
import {IGeneralDistributionAgreementV1, ISuperfluidPool, PoolConfig} from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/gdav1/IGeneralDistributionAgreementV1.sol";

import "./PureSuperToken.sol";
import "./TradeExecutor.sol";

contract SuperFluidFlow is CFASuperAppBase {
    using SuperTokenV1Library for ISuperToken;

    // Custom Errors
    error OnlyOwner();
    error OnlyFundManager();
    error FundDurationTooShort();
    error SubscriptionPeriodEnded();
    // error TradingPeriodEnded();
    error FundStillActive();
 
    address public owner;
    ISuperToken public acceptedToken;
    address public fundManager;
    ISuperToken public fundToken;

    uint256 public totalStreamed;

    bool public isFundActive;

    // Timestamp variables
    uint256 public fundEndTime;
    uint256 public subscriptionDeadline;

    address public factory;
    address public tradeExecutor;
    ISuperfluid public host;

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

    function createFundFlow(address user) external {
        int96 rate = acceptedToken.getFlowRate(user, address(this));
        fundToken.createFlow(user, rate);
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
        string _fundTokenName,
        string _fundTokenSymbol);

    event UserWithdrawn(address indexed user, uint256 fundTokensRedeemed, uint256 amountReceived);

    constructor(ISuperfluid _host) CFASuperAppBase(_host) {
        owner = msg.sender;
        host = _host;
    }

    function initialize(
        ISuperToken _acceptedToken, 
        address _fundManager,
        uint256 _fundDuration,
        uint256 _subscriptionDuration,
        address _factory,
        string memory _fundTokenName,
        string memory _fundTokenSymbol,
        address _tradeExec
    ) external {
        if (msg.sender != owner) revert OnlyOwner();
        if (_fundDuration <= _subscriptionDuration) revert FundDurationTooShort();
        
        acceptedToken = _acceptedToken;
        fundManager = _fundManager;
        tradeExecutor = _tradeExec;
        
        fundEndTime = block.timestamp + _fundDuration;
        subscriptionDeadline = block.timestamp + _subscriptionDuration;
        factory = _factory;
    
        isFundActive = true;

        // Deploy new PureSuperTokenProxy
        PureSuperTokenProxy tokenProxy = new PureSuperTokenProxy();
        
        // Get SuperToken factory from host
        ISuperTokenFactory superTokenFactory = ISuperTokenFactory(host.getSuperTokenFactory());
        
        // Initialize the token with 1 billion units (assuming 18 decimals)
        uint256 initialSupply = 1_000_000_000 * 1e18;
        tokenProxy.initialize(
            superTokenFactory,
            _fundTokenName,
            _fundTokenSymbol,
            address(this),
            initialSupply
        );
        
        fundToken = ISuperToken(address(tokenProxy));

        emit FundFlow(
            _acceptedToken,
            _fundManager,
            _fundDuration,
            _subscriptionDuration,
            _factory,
            _fundTokenName,
            _fundTokenSymbol
        );
    }



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
        
        if (block.timestamp > subscriptionDeadline) {
            // send back the tokens if subscription deadline has passed
            newCtx = acceptedToken.createFlowWithCtx(sender, senderFlowRate, ctx);
            return newCtx;
        }

        newCtx = ctx;

        
        // Start fund token stream to the sender
        newCtx = fundToken.createFlowWithCtx(sender, senderFlowRate, ctx);
        // No flow event emitted per your request

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
        ISuperToken superToken,
        address sender,
        int96 previousflowRate,
        uint256 lastUpdated,
        bytes calldata ctx
    ) internal override returns (bytes memory newCtx) {
        uint256 timeElapsed = block.timestamp - lastUpdated;
        totalStreamed += uint256(uint96(previousflowRate)) * timeElapsed;

        int96 currentFlowRate = superToken.getFlowRate(sender, address(this));
        
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
        int96 previousFlowRate,
        uint256 lastUpdated,
        bytes calldata ctx
    ) internal override returns (bytes memory newCtx) {
        uint256 timeElapsed = block.timestamp - lastUpdated;
        totalStreamed += uint256(uint96(previousFlowRate)) * timeElapsed;

        // Delete fund token stream to the sender
        newCtx = fundToken.deleteFlowWithCtx(address(this), sender, ctx);
        return newCtx;

    }

    // function downgradeAcceptedToken() external onlyFundManager {
    //     acceptedToken.downgrade(acceptedToken.balanceOf(address(this)));
    // }

    function executeTrade(
        address tokenIn,
        address tokenOut, 
        uint256 amountIn,
        uint256 minAmountOut, 
        uint24 poolFee 
    ) external onlyFundManager {
        // if (block.timestamp > fundEndTime) revert TradingPeriodEnded();

        acceptedToken.downgrade(acceptedToken.balanceOf(address(this)));

        IERC20(tokenIn).approve(address(tradeExecutor), amountIn);

        uint256 amountOut = TradeExecutor(tradeExecutor).executeSwap(
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

    function closeFund() external onlyFundManager {
        if (isFundActive){
            uint256 currentBalance = acceptedToken.balanceOf(address(this));
        
            isFundActive = false;

            // Calculate profit (if any)
            if (currentBalance > totalStreamed) {
                uint256 profitInUSD = currentBalance - totalStreamed;
                // Fund manager gets 10% of profits
                uint256 managerShare = (profitInUSD * 10) / 100;
                
                // Transfer manager's share
                acceptedToken.transfer(fundManager, managerShare);
            }

            emit FundClosed();
        }
    
    }


    function withdraw() external {
        if (isFundActive) revert FundStillActive();
        
        uint256 userFundTokenBalance = fundToken.balanceOf(msg.sender);

        // Calculate user's proportional share of the total assets
        uint256 totalFundTokenSupply = fundToken.totalSupply();
        uint256 contractBalance = acceptedToken.balanceOf(address(this));
        uint256 userShare = (contractBalance * userFundTokenBalance) / totalFundTokenSupply;

        // Burn the user's fund tokens
        fundToken.transferFrom(msg.sender, address(this), userFundTokenBalance);

        // Transfer the proportional share of accepted tokens to the user
        acceptedToken.transfer(msg.sender, userShare);

        emit UserWithdrawn(msg.sender, userFundTokenBalance, userShare);
    }
}
