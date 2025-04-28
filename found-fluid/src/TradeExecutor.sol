// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IV3SwapRouter.sol";

contract TradeExecutor is Ownable {
    address public UNISWAP_V3_ROUTER;

    mapping(address => bool) public whitelistedTokens;
    event UniswapV3RouterUpdated(address indexed oldRouter, address indexed newRouter);
    event TokenWhitelistStatusUpdated(address indexed token, bool status);
    event SwapExecuted(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed trader
    );

    /**
     * @dev Initialize the contract with the Uniswap V3 router address
     * @notice This can only be called once during deployment
     * @param _uniswapV3Router Address of the Uniswap V3 router
     */
    constructor(address _uniswapV3Router) {
        UNISWAP_V3_ROUTER = _uniswapV3Router; 
    }

    /**
     * @dev Updates the Uniswap V3 router address
     * @notice Can only be called by the contract owner
     * @param _uniswapV3Router New address of the Uniswap V3 router
     */
    function setUniswapV3Router(address _uniswapV3Router) external onlyOwner {
        address oldRouter = UNISWAP_V3_ROUTER;
        UNISWAP_V3_ROUTER = _uniswapV3Router;
        emit UniswapV3RouterUpdated(oldRouter, _uniswapV3Router);
    }

    /**
     * @dev Sets the whitelist status for a token
     * @notice Can only be called by the contract owner
     * @param _token Address of the token to update
     * @param _status New whitelist status for the token
     */
    function setWhitelistedToken(address _token, bool _status) external onlyOwner {
        whitelistedTokens[_token] = _status;
        emit TokenWhitelistStatusUpdated(_token, _status);
    }

    error TokenNotWhitelisted();

    /**
     * @notice Executes a swap on UniswapV3.
     * @dev This function executes a swap on UniswapV3 using the provided parameters.
     * @param tokenIn Address of the token being sold.
     * @param tokenOut Address of the token being bought.
     * @param amountIn Amount of tokenIn to swap.
     * @param minAmountOut Minimum amount of tokenOut expected.
     * @param fee The pool fee (in hundredths of a bip, e.g. 3000 means 0.3%).
     * @return amountOut The actual amount out after the swap.
     */
    function executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint24 fee
    ) external returns (uint256 amountOut) {
        if (!whitelistedTokens[tokenIn] || !whitelistedTokens[tokenOut]) revert TokenNotWhitelisted();
        // Approve the Uniswap router to spend tokenIn
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).approve(UNISWAP_V3_ROUTER, amountIn);

        IV3SwapRouter.ExactInputSingleParams memory params = IV3SwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: msg.sender,
            amountIn: amountIn,
            amountOutMinimum: minAmountOut,
            sqrtPriceLimitX96: 0
        });

        amountOut = IV3SwapRouter(UNISWAP_V3_ROUTER).exactInputSingle(params);
        emit SwapExecuted(tokenIn, tokenOut, amountIn, amountOut, msg.sender);
    }
}