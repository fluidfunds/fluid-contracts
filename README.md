# FluidFund

**A Decentralized Investment Pool Platform with Real-Time Streaming Contributions**

FluidFund enables investors to contribute continuously to a fund manager's pool via Superfluid streams. The fund manager invests the pooled USDC on behalf of the investors. This README explains the backend smart contract architecture and the integration with decentralized exchanges (DEXs) like Uniswap, utilizing whitelabeled tokens for trading.

---

## Backend Smart Contract Architecture

### Overview

The FluidFund platform is built on Ethereum-compatible networks, leveraging smart contracts to manage investment pools, user contributions, and fund manager activities. The key components include:

1. **Superfluid Streaming Contracts**: Enables continuous streaming of USDC (wrapped as USDCx) from users to the investment pool.

2. **Investment Pool Contract**: Aggregates user contributions and records pool allocations.

3. **Fund Manager Contract**: Allows the fund manager to execute trades on behalf of the pool within predefined constraints.

4. **Integration with DEXs**: Executes trades using protocols like Uniswap, restricted to whitelisted tokens.

---

### Smart Contract Components

#### 1. Streaming Contributions

- **Superfluid Protocol**: Users start a Superfluid stream of USDCx to the Investment Pool Contract.

- **USDCx Token**: An ERC20 wrapper of USDC that supports Superfluid's streaming capabilities.

- **Stream Management**: Users can start, adjust, or stop their streams at any time.

#### 2. Investment Pool Contract

- **Pool Balance**: Accumulates USDCx contributions from all streaming users.

- **Allocation Mapping**: Records each user's share of the pool based on their streaming contributions over time.

- **Accounting**: Keeps track of total inflows, outflows, and individual user balances.

- **Access Control**: Only the designated fund manager can execute investment actions.

#### 3. Fund Manager Contract

- **Investment Execution**: The fund manager interacts with this contract to place trades on behalf of the pool.

- **Functionality**:

  - **Trade Function**: Allows the fund manager to swap tokens on DEXs within the permitted token list.

  - **Profit Realization**: The fund manager can realize profits/losses and update the pool balances accordingly.

- **Security Measures**:

  - **Whitelisted Tokens**: Only specific tokens approved by the platform can be traded to prevent unauthorized activities.

  - **Trade Limits**: Possible implementation of limits on trade sizes or frequency to mitigate risks.

- **Role-Based Access Control**: Using OpenZeppelin's Access Control to ensure only authorized fund managers can execute trades.

#### 4. User Withdrawals

- **Withdrawal Requests**: Users can request to withdraw their share of realized profits and principal.

- **Redemption Process**: Upon realization of profits/losses by the fund manager, users can withdraw their updated balances.

- **Emergency Withdrawal**: Possible implementation of an emergency function to allow users to withdraw their principal under certain conditions.

---

## Integration with DEXs

### Trading via Uniswap

- **Uniswap V3 Integration**: The Fund Manager Contract integrates with Uniswap's smart contracts to execute token swaps.

- **Whitelabeled Tokens**:

  - **Definition**: Tokens that are specifically approved for trading within the platform.

  - **Purpose**: To restrict trading to safe, vetted assets and prevent exposure to high-risk or malicious tokens.

- **Implementation**:

  - **Whitelisted Token List**: Maintained within the Fund Manager Contract or via an external registry.

  - **Trade Function Constraints**: The trade function checks that only whitelisted tokens are involved before executing.

- **Swap Execution**:

  - **Function Call**: The fund manager calls the `trade` function, specifying input and output tokens, amounts, and other parameters.

  - **Routing**: The contract interacts with Uniswap's Router contracts to perform swaps.

  - **Slippage and Price Controls**: Parameters to prevent unfavorable trading conditions.

### Security and Compliance

- **Reentrancy Guards**: Protects against reentrancy attacks during trade execution.

- **Input Validation**: Ensures that all function inputs are within acceptable ranges and formats.

- **Events and Logging**: Emits events for all significant actions, aiding transparency and auditability.

---

## Detailed Workflow

1. **User Contribution**:

   - Users start a Superfluid stream of USDCx to the Investment Pool Contract.
   - The contract updates the user's contribution record in real-time.

2. **Pooling Funds**:

   - The Investment Pool Contract aggregates all incoming streams.
   - Total pool balance is updated continuously as streams flow in or are adjusted/stopped.

3. **Fund Manager Action**:

   - The fund manager monitors the pool balance and decides when to execute trades.
   - Using the Fund Manager Contract, they execute trades within the whitelisted tokens on Uniswap.

4. **Trade Execution**:

   - The contract verifies that the trade involves only whitelisted tokens.
   - Interacts with Uniswap's contracts to perform the swap.
   - Updates the pool's token holdings accordingly.

5. **Profit/Loss Realization**:

   - When investments are liquidated, profits or losses are realized.
   - The fund manager updates the Investment Pool Contract with the new balances.

6. **User Withdrawal**:

   - Users can request withdrawals based on their share of the pool.
   - The contract calculates the user's entitlement, including realized profits/losses.
   - Funds are transferred back to the user, possibly as USDCx.

---

## Smart Contract Functions Overview

### Investment Pool Contract Functions


- `getUserAllocation(address user)`: Returns the user's current share of the pool.

- `withdraw(uint256 amount)`: Allows the user to withdraw available funds.

### Fund Manager Contract Functions

- `trade(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut)`: Executes a trade on Uniswap.

  - **Validations**:

    - `tokenIn` and `tokenOut` are whitelisted.

    - `amountIn` does not exceed pool balance.

- `realizeProfits()`: Updates the pool's balances to reflect profits or losses.

- `setWhitelistedTokens(address[] tokens)`: (Admin function) Updates the list of whitelisted tokens.

---

## Considerations

- **Access Control**: Only authorized fund managers can execute trades or modify critical parameters.

- **User Protections**:

  - **Withdrawal Rights**: Users can withdraw their contributions under certain conditions.

---

## Future Enhancements

- **Dynamic Whitelists**: Implement governance mechanisms for updating the whitelisted tokens list.

- **Multiple Fund Managers**: Support for multiple fund managers, each managing separate pools.

- **Fee Structures**: Introduce performance fees or management fees, properly accounted for in the contracts.

- **Integration with Other DEXs**: Expand trading capabilities to include other decentralized exchanges or liquidity protocols.

---
