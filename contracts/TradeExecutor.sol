// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";

contract TradeExecutor {
    // Set the router address (in this example, UniswapV3’s router)
    address public constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    /**
     * @notice Executes a swap on UniswapV3.
     * @param tokenIn Address of the token being sold.
     * @param tokenOut Address of the token being bought.
     * @param amountIn Amount of tokenIn to swap.
     * @param minAmountOut Minimum amount of tokenOut expected.
     * @param fee The pool fee (in hundredths of a bip, e.g. 3000 means 0.3%).
     * @param recipient The address that should receive the swapped tokens.
     * @return amountOut The actual amount out after the swap.
     */
    function executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint24 fee,
        address recipient
    ) external returns (uint256 amountOut) {
        // Approve the Uniswap router to spend tokenIn
        TransferHelper.safeApprove(tokenIn, UNISWAP_V3_ROUTER, amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: recipient,
            deadline: block.timestamp + 15 minutes,
            amountIn: amountIn,
            amountOutMinimum: minAmountOut,
            sqrtPriceLimitX96: 0
        });

        amountOut = ISwapRouter(UNISWAP_V3_ROUTER).exactInputSingle(params);
    }
}