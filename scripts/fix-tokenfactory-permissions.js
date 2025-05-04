const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
  console.log("Fixing TokenFactory permissions by updating linkDatatoken function...");

  // Read deployment info
  const deploymentInfo = JSON.parse(fs.readFileSync("deployment-local.json", "utf8"));
  console.log("Using deployment info:", deploymentInfo);

  const [deployer] = await ethers.getSigners();
  console.log(`Using deployer address: ${deployer.address}`);

  // Get contract instances
  const DataNFT = await ethers.getContractFactory("DataNFT");
  const dataNFT = DataNFT.attach(deploymentInfo.dataNFT);

  const TokenFactory = await ethers.getContractFactory("TokenFactory");
  const tokenFactory = TokenFactory.attach(deploymentInfo.tokenFactory);

  // Check current owner of DataNFT
  const dataNFTOwner = await dataNFT.owner();
  console.log(`Current DataNFT owner: ${dataNFTOwner}`);

  // Check current owner of TokenFactory
  const tokenFactoryOwner = await tokenFactory.owner();
  console.log(`Current TokenFactory owner: ${tokenFactoryOwner}`);

  // Check if the DataNFT owner is the deployer
  if (dataNFTOwner.toLowerCase() !== deployer.address.toLowerCase()) {
    console.log("❌ DataNFT is not owned by the deployer. Cannot proceed.");
    return;
  }

  console.log("Setting TokenFactory contract as an approved operator for the DataNFT contract...");
  
  // Create a temporary NFT to test with
  console.log("Creating a test NFT...");
  const metadataURI = "ipfs://QmTestFix";
  const datasetCID = "ipfs://QmDatasetCIDFix";
  const datasetHash = ethers.encodeBytes32String("test-fix");
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
  
  // Now link a token manually
  console.log("Creating a token and manually linking it with the DataNFT...");
  
  // Deploy DataToken directly
  const DataToken = await ethers.getContractFactory("DataToken");
  const datatoken = await DataToken.deploy(
    "Test Fix Token",
    "TFIX",
    ethers.parseUnits("1000000", 18), // 1 million tokens
    ethers.parseUnits("0.01", 18),    // 0.01 ETH price
    18                                // 18 decimals
  );
  
  await datatoken.waitForDeployment();
  const datatokenAddress = await datatoken.getAddress();
  console.log(`Deployed test token at address: ${datatokenAddress}`);
  
  // Transfer ownership of the token to the deployer
  await datatoken.transferOwnership(deployer.address);
  console.log("Transferred token ownership to deployer");
  
  // Create a storage mapping entry in the DataNFT for this token
  console.log("Linking the token to the NFT using linkDatatoken...");
  try {
    const linkTx = await dataNFT.linkDatatoken(nftId, datatokenAddress);
    await linkTx.wait();
    console.log("✅ Successfully linked token to NFT");
  } catch (error) {
    console.error("❌ Failed to link token:", error.message);
    
    if (error.message.includes("execution reverted")) {
      // Try to extract the revert reason
      const reason = error.message.split("reason=")[1]?.split('"')[1] || "Unknown reason";
      console.log(`Contract reverted with reason: ${reason}`);
    }
  }
  
  console.log("\nNow attempting to use TokenFactory's createToken function...");
  try {
    const tokenName = "Factory Test Token";
    const tokenSymbol = "FTT";
    
    // Use the TokenFactory to create another token
    const createTokenTx = await tokenFactory.createToken(
      nftId,
      tokenName,
      tokenSymbol,
      0, // Use default initial supply
      0, // Use default token price
      0  // Use default decimals
    );
    
    await createTokenTx.wait();
    console.log("✅ Successfully created token using TokenFactory");
  } catch (error) {
    console.error("❌ Failed to create token using TokenFactory:", error.message);
    
    if (error.message.includes("execution reverted")) {
      // Try to extract the revert reason
      const reason = error.message.split("reason=")[1]?.split('"')[1] || "Unknown reason";
      console.log(`Contract reverted with reason: ${reason}`);
      
      if (reason.includes("TokenAlreadyExists")) {
        console.log("This is expected since we already linked a token to this NFT");
      }
    }
  }
  
  console.log("\nPermission check complete. See above results to determine if further action is needed.");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 