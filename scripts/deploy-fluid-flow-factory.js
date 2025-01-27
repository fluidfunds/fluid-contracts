const { ethers } = require("hardhat");

async function main() {
  // For local testing, you might want to use placeholder addresses
  // Replace these with actual addresses when deploying to testnet/mainnet
  const HOST_ADDRESS = "0x0000000000000000000000000000000000000001"; 
  const CFA_ADDRESS = "0x0000000000000000000000000000000000000002";   
  const USDCX_ADDRESS = "0x0000000000000000000000000000000000000003"; 

  console.log("Deploying FluidFlowFactory...");

  // Get the contract factory
  const FluidFlowFactory = await ethers.getContractFactory("FluidFlowFactory");

  // Deploy the contract
  const fluidFlowFactory = await FluidFlowFactory.deploy(
    HOST_ADDRESS,
    CFA_ADDRESS,
    USDCX_ADDRESS
  );

  // Wait for deployment to finish
  await fluidFlowFactory.deployed();

  console.log("FluidFlowFactory deployed to:", fluidFlowFactory.address);

  // Verify contract on Etherscan (if not on local network)
  if (network.name !== "hardhat" && network.name !== "localhost") {
    console.log("Waiting for block confirmations...");
    await fluidFlowFactory.deployTransaction.wait(6); // Wait for 6 block confirmations

    console.log("Verifying contract...");
    await hre.run("verify:verify", {
      address: fluidFlowFactory.address,
      constructorArguments: [HOST_ADDRESS, CFA_ADDRESS, USDCX_ADDRESS],
    });
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 