// scripts/manage-link.js
const { ethers } = require("hardhat");

// Polygon Amoy Testnet LINK Token Address
const LINK_TOKEN_ADDRESS = "0x326C977E6efc84E512bB9C30f76E30c160eD06FB";

async function main() {
  console.log("LINK Token Management for DataX Marketplace");
  console.log("===========================================");

  const [signer] = await ethers.getSigners();
  console.log(`Using account: ${signer.address}`);

  // Replace with your deployed contract addresses
  const MARKETPLACE_ADDRESS = "YOUR_MARKETPLACE_ADDRESS"; 
  const DATANFT_ADDRESS = "YOUR_DATANFT_ADDRESS";

  // Get LINK token contract
  const linkToken = await ethers.getContractAt("IERC20", LINK_TOKEN_ADDRESS);
  
  // Check LINK balance
  const linkBalance = await linkToken.balanceOf(signer.address);
  console.log(`Current LINK balance: ${ethers.formatUnits(linkBalance, 18)} LINK`);

  if (linkBalance.isZero()) {
    console.error("Error: No LINK tokens available. Make sure you have LINK tokens in your wallet.");
    process.exit(1);
  }

  // Menu of actions
  console.log("\nWhat would you like to do?");
  console.log("1. Approve LINK tokens for the marketplace");
  console.log("2. Check existing allowance for the marketplace");
  console.log("3. List a dataset for sale with LINK price");
  console.log("4. Buy a dataset using LINK tokens");
  
  // Using hardcoded option for this script - you can modify as needed
  const option = process.env.OPTION || "1"; 
  
  switch (option) {
    case "1":
      // Approve LINK tokens to be spent by the marketplace
      const approvalAmount = process.env.AMOUNT 
        ? ethers.parseUnits(process.env.AMOUNT, 18) 
        : ethers.parseUnits("10", 18); // Default 10 LINK
        
      console.log(`Approving ${ethers.formatUnits(approvalAmount, 18)} LINK for marketplace at ${MARKETPLACE_ADDRESS}...`);
      
      try {
        const approveTx = await linkToken.approve(MARKETPLACE_ADDRESS, approvalAmount);
        console.log(`Transaction hash: ${approveTx.hash}`);
        await approveTx.wait();
        console.log("LINK tokens approved successfully!");
        
        // Check updated allowance
        const newAllowance = await linkToken.allowance(signer.address, MARKETPLACE_ADDRESS);
        console.log(`New marketplace allowance: ${ethers.formatUnits(newAllowance, 18)} LINK`);
      } catch (error) {
        console.error("Error approving LINK tokens:", error.message);
      }
      break;
      
    case "2":
      // Check current allowance
      try {
        const allowance = await linkToken.allowance(signer.address, MARKETPLACE_ADDRESS);
        console.log(`Current marketplace allowance: ${ethers.formatUnits(allowance, 18)} LINK`);
      } catch (error) {
        console.error("Error checking allowance:", error.message);
      }
      break;
      
    case "3":
      // List dataset for sale
      const tokenId = process.env.TOKEN_ID;
      if (!tokenId) {
        console.error("Error: TOKEN_ID environment variable required");
        process.exit(1);
      }
      
      const price = process.env.PRICE 
        ? ethers.parseUnits(process.env.PRICE, 18) 
        : ethers.parseUnits("5", 18); // Default 5 LINK
      
      try {
        // First approve marketplace for NFT
        const dataNFT = await ethers.getContractAt("IDataNFT", DATANFT_ADDRESS);
        const approveTx = await dataNFT.approve(MARKETPLACE_ADDRESS, tokenId);
        console.log(`NFT approval transaction hash: ${approveTx.hash}`);
        await approveTx.wait();
        console.log("NFT approved for marketplace");
        
        // List on marketplace
        const marketplace = await ethers.getContractAt("Marketplace", MARKETPLACE_ADDRESS);
        const listTx = await marketplace.listDataset(tokenId, price);
        console.log(`List transaction hash: ${listTx.hash}`);
        await listTx.wait();
        console.log(`Dataset #${tokenId} listed for ${ethers.formatUnits(price, 18)} LINK successfully!`);
      } catch (error) {
        console.error("Error listing dataset:", error.message);
      }
      break;
      
    case "4":
      // Buy dataset
      const datasetId = process.env.DATASET_ID;
      if (!datasetId) {
        console.error("Error: DATASET_ID environment variable required");
        process.exit(1);
      }
      
      try {
        const marketplace = await ethers.getContractAt("Marketplace", MARKETPLACE_ADDRESS);
        
        // Get dataset price first
        const dataset = await marketplace.getDataset(datasetId);
        console.log(`Dataset #${datasetId} price: ${ethers.formatUnits(dataset[0].price, 18)} LINK`);
        
        // Buy dataset
        const buyTx = await marketplace.buyDataset(datasetId);
        console.log(`Buy transaction hash: ${buyTx.hash}`);
        await buyTx.wait();
        console.log(`Dataset #${datasetId} purchased successfully!`);
      } catch (error) {
        console.error("Error buying dataset:", error.message);
      }
      break;
      
    default:
      console.log("Invalid option selected");
  }
}

// Usage examples:
// Check balance: node -e "require('./hardhat.config.js'); require('./scripts/manage-link.js')"
// Approve tokens: OPTION=1 AMOUNT=5 npx hardhat run scripts/manage-link.js --network amoy
// List dataset: OPTION=3 TOKEN_ID=1 PRICE=5 npx hardhat run scripts/manage-link.js --network amoy
// Buy dataset: OPTION=4 DATASET_ID=1 npx hardhat run scripts/manage-link.js --network amoy

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  }); 