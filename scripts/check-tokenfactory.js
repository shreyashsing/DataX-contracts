// scripts/check-tokenfactory.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
  console.log("Checking TokenFactory configuration...");

  // Read deployment info
  const deploymentInfo = JSON.parse(fs.readFileSync("deployment-local.json", "utf8"));
  console.log("Deployment info:", deploymentInfo);

  const tokenFactoryAddress = deploymentInfo.tokenFactory;
  const dataNFTAddress = deploymentInfo.dataNFT;

  console.log(`TokenFactory address: ${tokenFactoryAddress}`);
  console.log(`DataNFT address: ${dataNFTAddress}`);

  // Get contract instances
  const TokenFactory = await ethers.getContractFactory("TokenFactory");
  const tokenFactory = TokenFactory.attach(tokenFactoryAddress);

  // Check DataNFT address in TokenFactory
  const configuredDataNFTAddress = await tokenFactory.dataNFTContract();
  console.log(`DataNFT address configured in TokenFactory: ${configuredDataNFTAddress}`);

  if (configuredDataNFTAddress.toLowerCase() === dataNFTAddress.toLowerCase()) {
    console.log("✅ TokenFactory is correctly configured with the DataNFT address");
  } else {
    console.log("❌ TokenFactory has incorrect DataNFT address!");
    console.log("Setting the correct DataNFT address...");
    
    // Update the DataNFT address in TokenFactory
    const tx = await tokenFactory.setDataNFTContract(dataNFTAddress);
    await tx.wait();
    
    console.log("✅ DataNFT address updated successfully!");
    
    // Verify the update
    const updatedDataNFTAddress = await tokenFactory.dataNFTContract();
    console.log(`New DataNFT address in TokenFactory: ${updatedDataNFTAddress}`);
  }

  console.log("\nChecking contract code at addresses...");
  
  // Check if there's code at the TokenFactory address
  const tokenFactoryCode = await ethers.provider.getCode(tokenFactoryAddress);
  if (tokenFactoryCode === "0x" || tokenFactoryCode === "") {
    console.log("❌ No contract code found at TokenFactory address!");
  } else {
    console.log(`✅ Contract code found at TokenFactory address (${tokenFactoryCode.substring(0, 20)}...)`);
  }
  
  // Check if there's code at the DataNFT address
  const dataNFTCode = await ethers.provider.getCode(dataNFTAddress);
  if (dataNFTCode === "0x" || dataNFTCode === "") {
    console.log("❌ No contract code found at DataNFT address!");
  } else {
    console.log(`✅ Contract code found at DataNFT address (${dataNFTCode.substring(0, 20)}...)`);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 