const { ethers, network } = require("hardhat");

async function main() {
  // For local testing, you might want to use placeholder addresses
  // Replace these with actual addresses when deploying to testnet/mainnet
  const USDCX_ADDRESS = "0x1650581F573eAd727B92073B5Ef8B4f5B94D1648"; 
  const TRADE_EXEC = "0xFdB43deec35e10dd2AC758e63Ef28b337B30270f"

  console.log("Deploying FluidFlowFactory...");

  // Get the contract factory
  const FluidFlowFactory = await ethers.getContractFactory("FluidFlowFactory");

  // Deploy the contract with the accepted token (USDCx)
  const fluidFlowFactory = await FluidFlowFactory.deploy(USDCX_ADDRESS, TRADE_EXEC);

  // Wait for deployment to finish
  await fluidFlowFactory.waitForDeployment();

  // Get the deployed contract address
  const deployedAddress = await fluidFlowFactory.getAddress();
  
  console.log("FluidFlowFactory deployed to:", deployedAddress);

  // Verify contract on Etherscan (if not on local network)
  if (network.name !== "hardhat" && network.name !== "localhost") {
    console.log("Waiting for block confirmations...");
    
    // Wait for 6 blocks
    await fluidFlowFactory.deploymentTransaction().wait(6);

    console.log("Verifying contract...");
    await hre.run("verify:verify", {
      address: deployedAddress,
      constructorArguments: [USDCX_ADDRESS, TRADE_EXEC],
    });
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 