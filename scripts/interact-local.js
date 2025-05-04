// scripts/interact-local.js
const { ethers } = require("hardhat");
const fs = require("fs");

// Load the deployment addresses from the file
const loadDeployment = () => {
  try {
    const data = fs.readFileSync("deployment-local.json", "utf8");
    return JSON.parse(data);
  } catch (error) {
    console.error("Error loading deployment information:", error.message);
    console.log("Please run deploy-local.js first to deploy contracts");
    process.exit(1);
  }
};

async function main() {
  console.log("Interacting with DataX contracts on local chain...");
  
  // Get deployment information
  const deployment = loadDeployment();
  console.log("Using deployment:", deployment);
  
  // Get signers (accounts)
  const [owner, user1] = await ethers.getSigners();
  console.log(`Owner address: ${owner.address}`);
  console.log(`User1 address: ${user1.address}`);
  
  // Connect to deployed contracts
  const mockLink = await ethers.getContractAt("MockLINK", deployment.linkToken);
  const dataNFT = await ethers.getContractAt("DataNFT", deployment.dataNFT);
  const aiVerification = await ethers.getContractAt("AIVerification", deployment.aiVerification);
  const marketplace = await ethers.getContractAt("Marketplace", deployment.marketplace);
  
  // Check LINK balances
  const ownerLinkBalance = await mockLink.balanceOf(owner.address);
  console.log(`Owner LINK balance: ${ethers.formatUnits(ownerLinkBalance, 18)}`);
  
  // Send some LINK to user1
  console.log(`Transferring LINK tokens to ${user1.address}...`);
  const transferAmount = ethers.parseUnits("100", 18); // 100 LINK
  await mockLink.transfer(user1.address, transferAmount);
  console.log(`Transferred ${ethers.formatUnits(transferAmount, 18)} LINK tokens to ${user1.address}`);
  
  // Check user1's LINK balance
  const user1LinkBalance = await mockLink.balanceOf(user1.address);
  console.log(`User1 LINK balance: ${ethers.formatUnits(user1LinkBalance, 18)}`);
  
  // Add the owner as a verifier in AIVerification
  console.log("Adding owner as verifier...");
  const DEFAULT_ADMIN_ROLE = await aiVerification.DEFAULT_ADMIN_ROLE();
  const hasAdminRole = await aiVerification.hasRole(DEFAULT_ADMIN_ROLE, owner.address);
  console.log(`Owner has admin role: ${hasAdminRole}`);
  
  // Verify a dataset (simulate AI verification)
  console.log("Verifying a dataset...");
  const datasetHash = ethers.keccak256(ethers.toUtf8Bytes("Test Dataset 1"));
  const verificationHash = ethers.keccak256(ethers.toUtf8Bytes("Verification Result 1"));
  
  const verificationInput = {
    datasetHash: datasetHash,
    verificationHash: verificationHash,
    isVerified: true,
    qualityScore: 85,
    anomalies: 5,
    duplicates: 10,
    diversity: 90,
    biasScore: 80,
    datasetCID: "ipfs://QmTestDatasetHash",
    analysisReport: "ipfs://QmTestReportHash",
    isPrivate: false,
    decryptionKey: ethers.ZeroHash
  };
  
  await aiVerification.verifyDataset(verificationInput);
  console.log("Dataset verified successfully!");
  
  // Mint a DataNFT for the verified dataset
  console.log("Minting DataNFT...");
  const mintTx = await dataNFT.mintNFT(
    "ipfs://QmMetadataHash",
    "ipfs://QmTestDatasetHash",
    datasetHash,
    false,
    ethers.ZeroHash,
    owner.address
  );
  const mintReceipt = await mintTx.wait();
  
  // Find the token ID from the event
  const mintEvent = mintReceipt.logs.find(
    log => log.fragment && log.fragment.name === "DataNFTMinted"
  );
  const tokenId = mintEvent ? mintEvent.args[0] : 1;
  console.log(`Minted DataNFT with token ID: ${tokenId}`);
  
  // Link the DataNFT to the LINK token
  console.log("Linking DataNFT to LINK token...");
  await dataNFT.linkDatatoken(tokenId, deployment.linkToken);
  console.log(`Linked DataNFT #${tokenId} to LINK token at ${deployment.linkToken}`);
  
  // Approve LINK for marketplace
  console.log("Approving LINK tokens for marketplace...");
  const approveAmount = ethers.parseUnits("50", 18); // 50 LINK
  await mockLink.approve(deployment.marketplace, approveAmount);
  console.log(`Approved ${ethers.formatUnits(approveAmount, 18)} LINK tokens for marketplace`);
  
  // List the NFT for sale
  console.log("Listing DataNFT for sale...");
  await dataNFT.approve(deployment.marketplace, tokenId);
  const priceInLink = ethers.parseUnits("10", 18); // 10 LINK
  await marketplace.listDataset(tokenId, priceInLink);
  console.log(`Listed DataNFT #${tokenId} for ${ethers.formatUnits(priceInLink, 18)} LINK`);
  
  // User1 approves LINK and buys the dataset
  console.log("User1 buying the dataset...");
  await mockLink.connect(user1).approve(deployment.marketplace, priceInLink);
  await marketplace.connect(user1).buyDataset(tokenId);
  console.log(`User1 purchased DataNFT #${tokenId} successfully!`);
  
  // Check ownership
  const newOwner = await dataNFT.ownerOf(tokenId);
  console.log(`New owner of DataNFT #${tokenId}: ${newOwner}`);
  
  console.log("\nAll interactions completed successfully!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error:", error);
    process.exit(1);
  }); 