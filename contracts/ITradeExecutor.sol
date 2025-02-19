// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma abicoder v2;

interface ITradeExecutor {
    // Custom errors
    error TokenNotWhitelisted();

    /**
     * @notice Sets the whitelist status for a token
     * @param _token The token address to whitelist/de-whitelist
     * @param _status The whitelist status to set
     */
    function setWhitelistedToken(address _token, bool _status) external;

    /**
     * @notice Executes a swap on UniswapV3
     * @param tokenIn Address of the token being sold
     * @param tokenOut Address of the token being bought
     * @param amountIn Amount of tokenIn to swap
     * @param minAmountOut Minimum amount of tokenOut expected
     * @param fee The pool fee (in hundredths of a bip, e.g. 3000 means 0.3%)
     * @return amountOut The actual amount out after the swap
     */
    function executeSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint24 fee
    ) external returns (uint256 amountOut);

    /**
     * @notice Gets the Uniswap V3 Router address
     * @return The address of the Uniswap V3 Router
     */
    function UNISWAP_V3_ROUTER() external view returns (address);

    /**
     * @notice Checks if a token is whitelisted
     * @param token The token address to check
     * @return bool Whether the token is whitelisted
     */
    function whitelistedTokens(address token) external view returns (bool);
}