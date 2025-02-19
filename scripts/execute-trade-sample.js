const { ethers } = require("hardhat");

async function main() {
    // fake tokens I minted on sepolia
  const fDAIx = "0x9ce2062b085a2268e8d769ffc040f6692315fd2c"; 
  const fUSDCx = "0xb598e6c621618a9f63788816ffb50ee2862d443b"; 
  
  // Get the deployed TradeExecutor contract address
  const TRADE_EXECUTOR_ADDRESS = "0xFdB43deec35e10dd2AC758e63Ef28b337B30270f"; // ETH SEPOLIA chain
  
  console.log("Testing trade execution...");

  // Get the ERC20 contract instance for the input token
  const tokenInContract = await ethers.getContractAt("IERC20", fDAIx);
  const tokenOutContract = await ethers.getContractAt("IERC20", fUSDCx);

  // Approve the TradeExecutor contract to spend tokens
  console.log("Approving tokens...");
  const amountIn = ethers.parseEther("10");
  const approveTx = await tokenInContract.approve(TRADE_EXECUTOR_ADDRESS, amountIn);
  await approveTx.wait();
  console.log("Approval successful!");

  // approve the token out contract to spend tokens
  const approveTx2 = await tokenOutContract.approve(TRADE_EXECUTOR_ADDRESS, amountIn);
  await approveTx2.wait();
  console.log("Approval successful!");

  // Get the TradeExecutor contract instance
  const tradeExecutor = await ethers.getContractAt("TradeExecutor", TRADE_EXECUTOR_ADDRESS);

  // Example parameters for the swap
  const tokenOut = fUSDCx;
  const minAmountOut = 0;//ethers.parseEther("11");
  const poolFee = 3000; // 0.3% fee tier

  try {
    console.log(`Executing swap:
      Token In: ${fDAIx}
      Token Out: ${tokenOut}
      Amount In: ${amountIn}
      Min Amount Out: ${minAmountOut}
      Pool Fee: ${poolFee}
    `);

    // Execute the swap
    const tx = await tradeExecutor.executeSwap(
      fDAIx,
      tokenOut,
      amountIn,
      minAmountOut,
      poolFee
    );

    // Wait for the transaction to be mined
    const receipt = await tx.wait();

    console.log("Trade executed successfully!");
    console.log("Transaction hash:", receipt.hash);

    // Get the amount received from the event
    const event = receipt.logs.find(log => 
      log.topics[0] === ethers.id("TradeExecuted(address,address,uint256,uint256,uint256,bool)")
    );

    if (event) {
      const decodedEvent = tradeExecutor.interface.parseLog(event);
      console.log("Amount received:", decodedEvent.args.amountOut.toString());
    }

  } catch (error) {
    console.error("Error executing trade:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
