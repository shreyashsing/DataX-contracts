const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
  console.log("Creating a workaround for token creation...");

  // Read deployment info
  const deploymentInfo = JSON.parse(fs.readFileSync("deployment-local.json", "utf8"));
  console.log("Using deployment info:", deploymentInfo);

  const [deployer] = await ethers.getSigners();
  console.log(`Using deployer address: ${deployer.address}`);

  // Get contract instances
  const DataNFT = await ethers.getContractFactory("DataNFT");
  const dataNFT = DataNFT.attach(deploymentInfo.dataNFT);

  // Create a test NFT
  console.log("\n==== Step 1: Creating a test NFT ====");
  const metadataURI = "ipfs://QmWorkaround";
  const datasetCID = "ipfs://QmDatasetCIDWorkaround";
  const datasetHash = ethers.encodeBytes32String("workaround-test");
  const isPrivate = false;
  const decryptionKey = ethers.encodeBytes32String(""); // Empty for public datasets
  
  const mintTx = await dataNFT.mintNFT(
    metadataURI,
    datasetCID,
    datasetHash,
    isPrivate,
    decryptionKey,
    deployer.address
  );
  
  const mintReceipt = await mintTx.wait();
  
  // Find the NFT ID from the event logs
  const nftMintedEvent = mintReceipt.logs
    .map(log => {
      try {
        return DataNFT.interface.parseLog(log);
      } catch (e) {
        return null;
      }
    })
    .filter(event => event && event.name === 'DataNFTMinted')[0];
  
  let nftId;
  if (nftMintedEvent) {
    nftId = nftMintedEvent.args.tokenId;
  } else {
    const transferEvent = mintReceipt.logs
      .map(log => {
        try {
          return DataNFT.interface.parseLog(log);
        } catch (e) {
          return null;
        }
      })
      .filter(event => event && event.name === 'Transfer')[0];
    
    nftId = transferEvent ? transferEvent.args.tokenId : null;
  }
  
  console.log(`Created test NFT with ID: ${nftId}`);
  
  // Step 2: Create the token directly
  console.log("\n==== Step 2: Creating a token directly ====");
  
  const DataToken = await ethers.getContractFactory("DataToken");
  const tokenName = "Workaround Token";
  const tokenSymbol = "WORK";
  const initialSupply = ethers.parseUnits("1000000", 18); // 1 million tokens
  const tokenPrice = ethers.parseUnits("0.01", 18);       // 0.01 ETH per token
  const decimals = 18;
  
  const datatoken = await DataToken.deploy(
    tokenName,
    tokenSymbol,
    initialSupply,
    tokenPrice,
    decimals
  );
  
  await datatoken.waitForDeployment();
  const datatokenAddress = await datatoken.getAddress();
  console.log(`Deployed token at address: ${datatokenAddress}`);
  
  // Step 3: Link the token to the NFT
  console.log("\n==== Step 3: Linking the token to the NFT ====");
  
  try {
    const linkTx = await dataNFT.linkDatatoken(nftId, datatokenAddress);
    await linkTx.wait();
    console.log("✅ Successfully linked token to NFT");
    
    // Step 4: Transfer token ownership to the NFT owner
    console.log("\n==== Step 4: Transferring token ownership to NFT owner ====");
    const nftOwner = await dataNFT.ownerOf(nftId);
    
    if (nftOwner.toLowerCase() !== deployer.address.toLowerCase()) {
      console.log(`Transferring token ownership to NFT owner: ${nftOwner}`);
      const transferOwnershipTx = await datatoken.transferOwnership(nftOwner);
      await transferOwnershipTx.wait();
      console.log("✅ Ownership transferred successfully");
    } else {
      console.log("Deployer is the NFT owner, no need to transfer ownership");
    }
    
    // Step 5: Verify the setup
    console.log("\n==== Step 5: Verifying the setup ====");
    const linkedToken = await dataNFT.getDatatoken(nftId);
    console.log(`Linked token address for NFT ${nftId}: ${linkedToken}`);
    
    if (linkedToken.toLowerCase() === datatokenAddress.toLowerCase()) {
      console.log("✅ Token is correctly linked to the NFT");
    } else {
      console.log("❌ Token link verification failed!");
    }
    
    const tokenOwner = await datatoken.owner();
    console.log(`Token owner: ${tokenOwner}`);
    
    if (tokenOwner.toLowerCase() === nftOwner.toLowerCase()) {
      console.log("✅ Token ownership verification passed");
    } else {
      console.log("❌ Token ownership verification failed!");
    }
    
    console.log("\n==== Workaround Complete ====");
    console.log("This demonstrates the direct deployment and linking approach as a workaround for TokenFactory issues.");
    console.log("NFT ID:", nftId);
    console.log("Token Address:", datatokenAddress);
    
  } catch (error) {
    console.error("Error in the workaround process:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
 