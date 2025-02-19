const { ethers, network } = require("hardhat");

async function main() {
  // For local testing, you might want to use placeholder addresses
  // Replace this with the actual Uniswap V3 Router address for the target network
  const UNISWAP_V3_ROUTER = "0x3bFA4769FB09eefC5a80d6E87c3B9C650f7Ae48E";

  console.log("Deploying TradeExecutor...");

  // Get the contract factory
  const TradeExecutor = await ethers.getContractFactory("TradeExecutor");

  // Deploy the contract with the Uniswap V3 Router address
  const tradeExecutor = await TradeExecutor.deploy(UNISWAP_V3_ROUTER);

  // Wait for deployment to finish
  await tradeExecutor.waitForDeployment();

  // Get the deployed contract address
  const deployedAddress = await tradeExecutor.getAddress();
  
  console.log("TradeExecutor deployed to:", deployedAddress);

  // Verify contract on Etherscan (if not on local network)
  if (network.name !== "hardhat" && network.name !== "localhost") {
    console.log("Waiting for block confirmations...");
    
    // Wait for 6 blocks
    await tradeExecutor.deploymentTransaction().wait(6);

    console.log("Verifying contract...");
    await hre.run("verify:verify", {
      address: deployedAddress,
      constructorArguments: [UNISWAP_V3_ROUTER],
    });
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
