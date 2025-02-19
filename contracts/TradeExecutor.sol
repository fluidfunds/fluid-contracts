// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IV3SwapRouter.sol";

contract TradeExecutor is Ownable {
    address public UNISWAP_V3_ROUTER;

    constructor(address _uniswapV3Router) {
        UNISWAP_V3_ROUTER = _uniswapV3Router; 
    }

    function setUniswapV3Router(address _uniswapV3Router) external onlyOwner {
        UNISWAP_V3_ROUTER = _uniswapV3Router; 
    }

    /**
     * @notice Executes a swap on UniswapV3.
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
        // Approve the Uniswap router to spend tokenIn
        TransferHelper.safeTransferFrom(tokenIn, msg.sender, address(this), amountIn);
        TransferHelper.safeApprove(tokenIn, UNISWAP_V3_ROUTER, amountIn);

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
    }
}