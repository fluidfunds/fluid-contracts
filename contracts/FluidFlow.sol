// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import { ISuperfluid, ISuperToken } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/superfluid/ISuperfluid.sol";
import { IConstantFlowAgreementV1 } from "@superfluid-finance/ethereum-contracts/contracts/interfaces/agreements/IConstantFlowAgreementV1.sol";

interface IFluidFlowFactory {
    function isTokenWhitelisted(address token) external view returns (bool);
}

contract FluidFlow is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Events
    event InvestmentReceived(address indexed investor, uint256 amount);
    event TradeExecuted(address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut);
    event StreamStarted(address indexed investor, int96 flowRate);
    event StreamUpdated(address indexed investor, int96 newFlowRate);
    event StreamStopped(address indexed investor);
    event ProfitsRealized(uint256 totalProfits);
    event WithdrawalProcessed(address indexed investor, uint256 amount);

    // State variables
    string public name;
    address public fundManager;
    uint256 public profitSharingBps;
    uint256 public subscriptionEndTime;
    uint256 public minInvestmentAmount;
    IFluidFlowFactory public factory;
    
    // Superfluid variables
    ISuperfluid public host;
    IConstantFlowAgreementV1 public cfa;
    ISuperToken public usdcx;
    
    // Uniswap variables
    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    uint24 public constant poolFee = 3000;

    // Investment tracking
    mapping(address => uint256) public investments;
    mapping(address => int96) public streamFlowRates;
    uint256 public totalInvestments;
    uint256 public totalProfits;
    mapping(address => uint256) public lastProfitIndex;

    constructor(
        string memory _name,
        address _fundManager,
        uint256 _profitSharingBps,
        uint256 _subscriptionEndTime,
        uint256 _minInvestmentAmount,
        address _factory,
        address _host,
        address _cfa,
        address _usdcx
    ) {
        require(_profitSharingBps <= 5000, "Profit share cannot exceed 50%");
        require(_subscriptionEndTime > block.timestamp, "Invalid subscription end time");
        require(_minInvestmentAmount > 0, "Min investment must be > 0");

        name = _name;
        fundManager = _fundManager;
        profitSharingBps = _profitSharingBps;
        subscriptionEndTime = _subscriptionEndTime;
        minInvestmentAmount = _minInvestmentAmount;
        factory = IFluidFlowFactory(_factory);
        
        host = ISuperfluid(_host);
        cfa = IConstantFlowAgreementV1(_cfa);
        usdcx = ISuperToken(_usdcx);
    }

    modifier onlyFundManager() {
        require(msg.sender == fundManager, "Only fund manager");
        _;
    }

    modifier beforeSubscriptionEnd() {
        require(block.timestamp <= subscriptionEndTime, "Subscription period ended");
        _;
    }

    /**
     * @notice Start or update a stream to the fund
     * @param flowRate New flow rate per second
     */
    function updateStream(int96 flowRate) external nonReentrant beforeSubscriptionEnd {
        require(flowRate >= 0, "Flow rate must be positive");
        
        int96 currentFlowRate = streamFlowRates[msg.sender];
        
        if (currentFlowRate == 0) {
            // Starting new stream
            require(
                uint256(uint96(flowRate)) * 30 days >= minInvestmentAmount,
                "Flow rate too low for min investment"
            );
            
            host.callAgreement(
                cfa,
                abi.encodeWithSelector(
                    cfa.createFlow.selector,
                    usdcx,
                    address(this),
                    flowRate,
                    new bytes(0)
                ),
                new bytes(0)
            );
            
            emit StreamStarted(msg.sender, flowRate);
        } else {
            // Updating existing stream
            host.callAgreement(
                cfa,
                abi.encodeWithSelector(
                    cfa.updateFlow.selector,
                    usdcx,
                    address(this),
                    flowRate,
                    new bytes(0)
                ),
                new bytes(0)
            );
            
            emit StreamUpdated(msg.sender, flowRate);
        }
        
        streamFlowRates[msg.sender] = flowRate;
    }

    /**
     * @notice Stop an existing stream
     */
    function stopStream() external nonReentrant {
        require(streamFlowRates[msg.sender] > 0, "No active stream");
        
        host.callAgreement(
            cfa,
            abi.encodeWithSelector(
                cfa.deleteFlow.selector,
                usdcx,
                msg.sender,
                address(this),
                new bytes(0)
            ),
            new bytes(0)
        );
        
        streamFlowRates[msg.sender] = 0;
        emit StreamStopped(msg.sender);
    }

    /**
     * @notice Execute a trade through Uniswap
     * @param tokenIn Token to sell
     * @param tokenOut Token to buy
     * @param amountIn Amount of tokenIn to sell
     * @param amountOutMinimum Minimum amount of tokenOut to receive
     */
    function executeTrade(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMinimum
    ) external onlyFundManager nonReentrant {
        require(
            factory.isTokenWhitelisted(tokenIn) && factory.isTokenWhitelisted(tokenOut),
            "Token not whitelisted"
        );

        IERC20(tokenIn).safeApprove(address(swapRouter), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: 0
            });

        uint256 amountOut = swapRouter.exactInputSingle(params);
        emit TradeExecuted(tokenIn, tokenOut, amountIn, amountOut);
    }

    /**
     * @notice Realize profits and update investor allocations
     * @param totalValue Current total value of the fund in USDC
     */
    function realizeProfits(uint256 totalValue) external onlyFundManager {
        require(totalValue >= totalInvestments, "Value cannot be less than investments");
        
        uint256 newProfits = totalValue - totalInvestments;
        uint256 managerFee = (newProfits * profitSharingBps) / 10000;
        totalProfits = newProfits - managerFee;
        
        // Transfer manager fee
        if (managerFee > 0) {
            usdcx.transfer(fundManager, managerFee);
        }
        
        emit ProfitsRealized(totalProfits);
    }

    /**
     * @notice Withdraw available funds
     * @param amount Amount to withdraw
     */
    function withdraw(uint256 amount) external nonReentrant {
        require(streamFlowRates[msg.sender] == 0, "Stop stream before withdrawal");
        require(amount <= getWithdrawableAmount(msg.sender), "Insufficient balance");

        uint256 investment = investments[msg.sender];
        require(amount <= investment, "Cannot withdraw more than investment");

        investments[msg.sender] -= amount;
        totalInvestments -= amount;
        
        usdcx.transfer(msg.sender, amount);
        emit WithdrawalProcessed(msg.sender, amount);
    }

    /**
     * @notice Calculate withdrawable amount for an investor
     * @param investor Address of the investor
     */
    function getWithdrawableAmount(address investor) public view returns (uint256) {
        uint256 investment = investments[investor];
        if (investment == 0) return 0;

        uint256 profitShare = (investment * totalProfits) / totalInvestments;
        return investment + profitShare;
    }

    /**
     * @notice Handle incoming super token (needed for Superfluid)
     */
    function afterAgreementCreated(
        ISuperToken _superToken,
        address _agreementClass,
        bytes32, // _agreementId,
        bytes calldata, // _agreementData
        bytes calldata, // _cbdata,
        bytes calldata _ctx
    ) external returns (bytes memory newCtx) {
        require(msg.sender == address(host), "Unauthorized host");
        require(_superToken == usdcx, "Unauthorized token");
        require(_agreementClass == address(cfa), "Unauthorized agreement");
        
        return _ctx;
    }
} 