## Foundry

# 1. Deploy contracts
forge script script/DeployTradeExecutor.s.sol --slow --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast --private-key <PRIVATE_KEY> --etherscan-api-key <ETHERSCAN_API_KEY> --verify
forge script script/DeployFluidFlowFactory.s.sol --slow --rpc-url https://ethereum-sepolia-rpc.publicnode.com --broadcast --private-key <PRIVATE_KEY> --etherscan-api-key <ETHERSCAN_API_KEY> --verify

# 2. Create a fund
export FACTORY_ADDRESS=0x...
export TRADE_EXECUTOR=0x...
forge script script/CreateFund.sol --rpc-url $RPC --broadcast -vvvv

# 3. Execute sample trade
forge script script/ExecuteTrade.sol --rpc-url $RPC --broadcast -vvvv