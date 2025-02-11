const { ethers } = require("hardhat");

async function main() {
  // Configuration parameters
  const ACCEPTED_TOKEN = "0x1650581F573eAd727B92073B5Ef8B4f5B94D1648"; // USDCx address
  const FUND_MANAGER = "0x97A1F968762B1D12c394e62AAA480998518a3744"; // Replace with actual fund manager address
  const FUND_DURATION = 30 * 24 * 60 * 60; // 30 days in seconds
  const SUBSCRIPTION_DURATION = 7 * 24 * 60 * 60; // 7 days in seconds
  const FACTORY_ADDRESS = "0xa0b41522e8aAF7ef1F03ADd489A65F258Bf8476c"; // Replace with deployed FluidFlowFactory address
  const FUND_TOKEN_NAME = "Test Fund Token";
  const FUND_TOKEN_SYMBOL = "TFT";

  console.log("Deploying SuperFluidFlow...");

  // Get the contract factory
  const SuperFluidFlow = await ethers.getContractFactory("SuperFluidFlow");

  // Deploy the contract
  const superFluidFlow = await SuperFluidFlow.deploy(
    ACCEPTED_TOKEN,
    FUND_MANAGER,
    FUND_DURATION,
    SUBSCRIPTION_DURATION,
    FACTORY_ADDRESS,
    FUND_TOKEN_NAME,
    FUND_TOKEN_SYMBOL
  );

  // Wait for deployment to finish
  await superFluidFlow.waitForDeployment();

  // Get the deployed contract address
  const deployedAddress = await superFluidFlow.getAddress();
  
  console.log("SuperFluidFlow deployed to:", deployedAddress);

  // Verify contract on Etherscan (if not on local network)
  if (network.name !== "hardhat" && network.name !== "localhost") {
    console.log("Waiting for block confirmations...");
    await superFluidFlow.deployTransaction.wait(6);

    console.log("Verifying contract...");
    await hre.run("verify:verify", {
      address: deployedAddress,
      constructorArguments: [
        ACCEPTED_TOKEN,
        FUND_MANAGER,
        FUND_DURATION,
        SUBSCRIPTION_DURATION,
        FACTORY_ADDRESS,
        FUND_TOKEN_NAME,
        FUND_TOKEN_SYMBOL
      ],
    });
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 