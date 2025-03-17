const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Data Exchange Marketplace", function () {
  let DataToken, DataNFT, AIVerification;
  let dataToken, dataNFT, aiVerification;
  let owner, user1, user2;

  const initialSupply = ethers.parseEther("1000");
  const tokenPrice = ethers.parseEther("0.01");
  const datasetHash = ethers.keccak256(ethers.toUtf8Bytes("ipfs://dataset123"));
  const tokenURI = "ipfs://metadata123";
  const listingPrice = ethers.parseEther("10");

  beforeEach(async function () {
    [owner, user1, user2] = await ethers.getSigners();

    // Deploy DataToken
    const DataTokenFactory = await ethers.getContractFactory("DataToken");
    dataToken = await DataTokenFactory.deploy("DataToken", "DTK", initialSupply, tokenPrice);
    await dataToken.waitForDeployment();

    // Deploy DataNFT
    const DataNFTFactory = await ethers.getContractFactory("DataNFT");
    dataNFT = await DataNFTFactory.deploy();
    await dataNFT.waitForDeployment();

    // Deploy AIVerification
    const AIVerificationFactory = await ethers.getContractFactory("AIVerification");
    aiVerification = await AIVerificationFactory.deploy(dataNFT.target);
    await aiVerification.waitForDeployment();

    // Set AIVerification contract in DataNFT
    await dataNFT.setAIVerificationContract(aiVerification.target);

    // Link DataNFT to DataToken (assuming setAssociatedNFT exists in DataToken)
    await dataToken.setAssociatedNFT(dataNFT.target, 1);
  });

  it("should verify a dataset and mint an NFT", async function () {
    // Simulate AI verification
    const verificationHash = ethers.keccak256(ethers.toUtf8Bytes("ai-result"));
    await aiVerification.verifyDataset(
      datasetHash,
      verificationHash,
      true, // isVerified
      92,   // qualityScore
      "ipfs://report123"
    );

    // Mint NFT
    const tx = await dataNFT.mintNFT(tokenURI, datasetHash);
    const receipt = await tx.wait();
    const tokenId = receipt.logs[0].args.tokenId;

    expect(await dataNFT.ownerOf(tokenId)).to.equal(owner.address);
    expect(await dataNFT.tokenURI(tokenId)).to.equal(tokenURI);
  });

  it("should fail to mint NFT if dataset is not verified", async function () {
    await expect(dataNFT.mintNFT(tokenURI, datasetHash)).to.be.revertedWith("Dataset not verified");
  });

  it("should link DataToken and list NFT for sale", async function () {
    // Verify dataset
    await aiVerification.verifyDataset(datasetHash, ethers.keccak256(ethers.toUtf8Bytes("ai-result")), true, 92, "ipfs://report123");

    // Mint NFT
    const tx = await dataNFT.mintNFT(tokenURI, datasetHash);
    const receipt = await tx.wait();
    const tokenId = receipt.logs[0].args.tokenId;

    // Link DataToken
    await dataNFT.linkDatatoken(tokenId, dataToken.target);

    // List NFT
    await dataNFT.listNFT(tokenId, listingPrice);
    const listing = await dataNFT.listings(tokenId);
    expect(listing.price).to.equal(listingPrice);
    expect(listing.isActive).to.be.true;
  });

  it("should allow buying an NFT with DataToken", async function () {
    // Verify and mint
    await aiVerification.verifyDataset(datasetHash, ethers.keccak256(ethers.toUtf8Bytes("ai-result")), true, 92, "ipfs://report123");
    const tx = await dataNFT.mintNFT(tokenURI, datasetHash);
    const receipt = await tx.wait();
    const tokenId = receipt.logs[0].args.tokenId;

    // Link DataToken and list
    await dataNFT.linkDatatoken(tokenId, dataToken.target);
    await dataNFT.listNFT(tokenId, listingPrice);

    // User1 buys tokens
    await dataToken.connect(user1).buyTokens(listingPrice, { value: ethers.parseEther("0.1") });
    await dataToken.connect(user1).approve(dataNFT.target, listingPrice);

    // User1 buys NFT
    await dataNFT.connect(user1).buyNFT(tokenId);
    expect(await dataNFT.ownerOf(tokenId)).to.equal(user1.address);
    expect((await dataNFT.listings(tokenId)).isActive).to.be.false;
    expect(await dataToken.balanceOf(owner.address)).to.equal(initialSupply + listingPrice);
  });

  it("should allow data access with payment", async function () {
    // Verify and mint
    await aiVerification.verifyDataset(datasetHash, ethers.keccak256(ethers.toUtf8Bytes("ai-result")), true, 92, "ipfs://report123");
    const tx = await dataNFT.mintNFT(tokenURI, datasetHash);
    const receipt = await tx.wait();
    const tokenId = receipt.logs[0].args.tokenId;

    // Link DataToken
    await dataNFT.linkDatatoken(tokenId, dataToken.target);

    // User1 buys tokens
    const accessAmount = ethers.parseEther("1");
    await dataToken.connect(user1).buyTokens(accessAmount, { value: ethers.parseEther("0.01") });
    await dataToken.connect(user1).approve(dataNFT.target, accessAmount);

    // User1 accesses data
    await dataNFT.connect(user1).accessData(tokenId, accessAmount);
    expect(await dataToken.balanceOf(owner.address)).to.equal(initialSupply + accessAmount);
  });

  it("should fail to access data without payment if not owner", async function () {
    // Verify and mint
    await aiVerification.verifyDataset(datasetHash, ethers.keccak256(ethers.toUtf8Bytes("ai-result")), true, 92, "ipfs://report123");
    const tx = await dataNFT.mintNFT(tokenURI, datasetHash);
    const receipt = await tx.wait();
    const tokenId = receipt.logs[0].args.tokenId;

    // Link DataToken
    await dataNFT.linkDatatoken(tokenId, dataToken.target);

    // User1 tries to access without payment
    await expect(dataNFT.connect(user1).accessData(tokenId, 0)).to.be.revertedWith("Payment required");
  });

  it("should restrict tokenURI to owner or DataToken holders", async function () {
    // Verify and mint
    await aiVerification.verifyDataset(datasetHash, ethers.keccak256(ethers.toUtf8Bytes("ai-result")), true, 92, "ipfs://report123");
    const tx = await dataNFT.mintNFT(tokenURI, datasetHash);
    const receipt = await tx.wait();
    const tokenId = receipt.logs[0].args.tokenId;

    // Link DataToken
    await dataNFT.linkDatatoken(tokenId, dataToken.target);

    // User1 without tokens can't see URI
    await expect(dataNFT.connect(user1).tokenURI(tokenId)).to.be.revertedWith("Must own at least 1 DataToken or the NFT");

    // Owner can see URI
    expect(await dataNFT.tokenURI(tokenId)).to.equal(tokenURI);

    // User1 buys tokens and can see URI
    await dataToken.connect(user1).buyTokens(ethers.parseEther("1"), { value: ethers.parseEther("0.01") });
    expect(await dataNFT.connect(user1).tokenURI(tokenId)).to.equal(tokenURI);
  });
});