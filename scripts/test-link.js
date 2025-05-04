// scripts/test-link.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
  console.log("Testing MockLINK token...");

  // Get deployment information
  try {
    const data = fs.readFileSync("deployment-local.json", "utf8");
    const deployment = JSON.parse(data);
    console.log("Using deployment:", deployment);
    
    // Get signer
    const [deployer] = await ethers.getSigners();
    console.log(`Using address: ${deployer.address}`);
    
    // Deploy a new MockLINK token for testing
    console.log("Deploying a fresh MockLINK token for testing...");
    const MockLINK = await ethers.getContractFactory("MockLINK");
    const mockLink = await MockLINK.deploy();
    await mockLink.waitForDeployment();
    const mockLinkAddress = await mockLink.getAddress();
    console.log(`Test MockLINK deployed to: ${mockLinkAddress}`);
    
    // Check balance
    const balance = await mockLink.balanceOf(deployer.address);
    console.log(`Deployer LINK balance: ${ethers.formatUnits(balance, 18)}`);
    
    // Transfer some tokens
    const transferAmount = ethers.parseUnits("100", 18);
    const [_, recipient] = await ethers.getSigners();
    console.log(`Transferring ${ethers.formatUnits(transferAmount, 18)} LINK to ${recipient.address}...`);
    const tx = await mockLink.transfer(recipient.address, transferAmount);
    await tx.wait();
    
    // Check recipient balance
    const recipientBalance = await mockLink.balanceOf(recipient.address);
    console.log(`Recipient LINK balance: ${ethers.formatUnits(recipientBalance, 18)}`);
    
    console.log("MockLINK test completed successfully!");
  } catch (error) {
    console.error("Error:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 