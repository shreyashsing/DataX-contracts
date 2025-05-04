// scripts/deploy-local.js
const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying DataX contracts to local development chain...");

  const [deployer] = await ethers.getSigners();
  console.log(`Deploying with address: ${deployer.address}`);
  
  const initialBalance = await ethers.provider.getBalance(deployer.address);
  console.log(`Initial account balance: ${ethers.formatEther(initialBalance)} ETH`);

  // Deploy mock LINK token first (since we don't have the real one on local chain)
  console.log("Deploying Mock LINK Token...");
  const MockLINK = await ethers.getContractFactory("MockLINK");
  const mockLink = await MockLINK.deploy();
  await mockLink.waitForDeployment();
  const linkTokenAddress = await mockLink.getAddress();
  console.log(`Mock LINK token deployed to: ${linkTokenAddress}`);

  // Mint some LINK tokens to the deployer
  console.log("Minting LINK tokens to deployer...");
  const mintAmount = ethers.parseUnits("1000", 18); // 1000 LINK
  await mockLink.mint(deployer.address, mintAmount);
  console.log(`Minted ${ethers.formatUnits(mintAmount, 18)} LINK tokens to ${deployer.address}`);

  // Deploy DataNFT contract
  console.log("Deploying DataNFT...");
  const DataNFT = await ethers.getContractFactory("DataNFT");
  const dataNFT = await DataNFT.deploy();
  await dataNFT.waitForDeployment();
  const dataNFTAddress = await dataNFT.getAddress();
  console.log(`DataNFT deployed to: ${dataNFTAddress}`);

  // Deploy TokenFactory contract
  console.log("Deploying TokenFactory...");
  const TokenFactory = await ethers.getContractFactory("TokenFactory");
  const tokenFactory = await TokenFactory.deploy(dataNFTAddress);
  await tokenFactory.waitForDeployment();
  const tokenFactoryAddress = await tokenFactory.getAddress();
  console.log(`TokenFactory deployed to: ${tokenFactoryAddress}`);

  // Deploy Marketplace with LINK token as the payment token
  console.log("Deploying Marketplace with Mock LINK as payment token...");
  const Marketplace = await ethers.getContractFactory("Marketplace");
  const marketplace = await Marketplace.deploy(linkTokenAddress, dataNFTAddress);
  await marketplace.waitForDeployment();
  const marketplaceAddress = await marketplace.getAddress();
  console.log(`Marketplace deployed to: ${marketplaceAddress}`);

  // Print summary of all deployed contracts
  console.log("\n-------- DEPLOYMENT SUMMARY --------");
  console.log(`DataNFT: ${dataNFTAddress}`);
  console.log(`TokenFactory: ${tokenFactoryAddress}`);
  console.log(`Mock LINK Token: ${linkTokenAddress}`);
  console.log(`Marketplace: ${marketplaceAddress}`);
  console.log("-----------------------------------\n");

  const finalBalance = await ethers.provider.getBalance(deployer.address);
  console.log(`Final account balance: ${ethers.formatEther(finalBalance)} ETH`);
  console.log(`Deployment cost: ${ethers.formatEther(initialBalance - finalBalance)} ETH`);

  // Save the deployment addresses to a file for easy access
  const fs = require("fs");
  const deploymentInfo = {
    network: "local",
    dataNFT: dataNFTAddress,
    tokenFactory: tokenFactoryAddress,
    linkToken: linkTokenAddress,
    marketplace: marketplaceAddress,
    timestamp: new Date().toISOString()
  };

  fs.writeFileSync(
    "deployment-local.json",
    JSON.stringify(deploymentInfo, null, 2)
  );
  console.log("Deployment information saved to deployment-local.json");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 