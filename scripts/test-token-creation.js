// scripts/test-token-creation.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
  console.log("Testing NFT minting and token creation...");

  // Read deployment info
  const deploymentInfo = JSON.parse(fs.readFileSync("deployment-local.json", "utf8"));
  console.log("Using deployment info:", deploymentInfo);

  const [deployer, testUser] = await ethers.getSigners();
  console.log(`Using deployer address: ${deployer.address}`);
  console.log(`Using test user address: ${testUser.address}`);

  // Get contract instances
  const DataNFT = await ethers.getContractFactory("DataNFT");
  const dataNFT = DataNFT.attach(deploymentInfo.dataNFT);

  const TokenFactory = await ethers.getContractFactory("TokenFactory");
  const tokenFactory = TokenFactory.attach(deploymentInfo.tokenFactory);

  // Step 1: Mint a new DataNFT
  console.log("\n==== Step 1: Minting a new DataNFT ====");
  const metadataURI = "ipfs://QmTest12345";
  const datasetCID = "ipfs://QmDatasetCID";
  const datasetHash = ethers.encodeBytes32String("test-dataset");
  const isPrivate = false;
  const decryptionKey = ethers.encodeBytes32String(""); // Empty for public datasets
  const recipient = deployer.address;
  const datasetName = "Test Dataset";

  console.log(`Minting NFT with metadata: ${metadataURI}`);
  console.log(`Dataset CID: ${datasetCID}`);
  console.log(`Dataset hash: ${datasetHash}`);
  console.log(`Recipient: ${recipient}`);

  const mintTx = await dataNFT.mintNFT(
    metadataURI,
    datasetCID,
    datasetHash,
    isPrivate,
    decryptionKey,
    recipient
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

  if (!nftMintedEvent) {
    const transferEvent = mintReceipt.logs
      .map(log => {
        try {
          return DataNFT.interface.parseLog(log);
        } catch (e) {
          return null;
        }
      })
      .filter(event => event && event.name === 'Transfer')[0];
    
    var nftId = transferEvent ? transferEvent.args.tokenId : null;
  } else {
    var nftId = nftMintedEvent.args.tokenId;
  }

  if (!nftId) {
    throw new Error("Failed to extract NFT ID from transaction logs");
  }

  console.log(`✅ Successfully minted DataNFT with ID: ${nftId}`);

  // Step 2: Create a token for the NFT
  console.log("\n==== Step 2: Creating a token for the NFT ====");
  const tokenName = "Test Token";
  const tokenSymbol = "TEST";
  
  // Check if a token already exists for this NFT
  const tokenExists = await tokenFactory.tokenExists(nftId);
  
  if (tokenExists) {
    const tokenAddress = await tokenFactory.tokensByNFTId(nftId);
    console.log(`Token already exists for NFT #${nftId} at address: ${tokenAddress}`);
  } else {
    console.log(`Creating token "${tokenName}" (${tokenSymbol}) for NFT #${nftId}...`);
    
    try {
      // Create a token with default parameters (0 means use defaults)
      const createTokenTx = await tokenFactory.createToken(
        nftId,
        tokenName,
        tokenSymbol,
        0, // Use default initial supply
        0, // Use default token price
        0  // Use default decimals
      );
      
      const createTokenReceipt = await createTokenTx.wait();
      
      // Find the token address from the logs
      const tokenCreatedEvent = createTokenReceipt.logs
        .map(log => {
          try {
            return TokenFactory.interface.parseLog(log);
          } catch (e) {
            return null;
          }
        })
        .filter(event => event && event.name === 'DataTokenCreated')[0];
      
      if (!tokenCreatedEvent) {
        console.log("⚠️ Could not find DataTokenCreated event in logs");
        console.log("Checking if token was created anyway...");
        
        // Check if a token was created despite not finding the event
        const tokenExistsAfter = await tokenFactory.tokenExists(nftId);
        
        if (tokenExistsAfter) {
          const tokenAddress = await tokenFactory.tokensByNFTId(nftId);
          console.log(`✅ Token created successfully at address: ${tokenAddress}`);
        } else {
          console.log("❌ Token creation failed");
        }
      } else {
        const tokenAddress = tokenCreatedEvent.args.tokenAddress;
        console.log(`✅ Token created successfully at address: ${tokenAddress}`);
      }
    } catch (error) {
      console.error("❌ Error creating token:", error.message);
      
      if (error.message.includes("execution reverted")) {
        // Try to extract the revert reason
        const reason = error.message.split("reason=")[1]?.split('"')[1] || "Unknown reason";
        console.log(`Contract reverted with reason: ${reason}`);
      }
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 