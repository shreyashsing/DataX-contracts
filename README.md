# DataX Marketplace Contracts

This repository contains the smart contracts for the DataX marketplace, which allows users to verify, mint, and trade datasets as NFTs.

## Local Development

To set up and run the contracts locally:

1. Install dependencies:
   ```bash
   npm install
   ```

2. Compile the contracts:
   ```bash
   npx hardhat compile
   ```

3. Start a local Hardhat node:
   ```bash
   npx hardhat node
   ```

4. In a separate terminal, deploy contracts to the local network:
   ```bash
   npx hardhat run scripts/deploy-local.js
   ```

5. Interact with the deployed contracts:
   ```bash
   npx hardhat run scripts/interact-local.js
   ```

## Features

- Data verification through AI verification system
- Dataset NFT minting with associated metadata
- Marketplace for listing and trading dataset NFTs
- LINK token integration for payments

## Contract Structure

- **DataNFT**: ERC-721 token representing ownership of datasets
- **AIVerification**: Contract for verifying datasets and their quality
- **Marketplace**: Trading platform for buying and selling DataNFTs
- **MockLINK**: Test LINK token for local development

## Testing

Run tests with:
```bash
npx hardhat test
```

## Local Development Guide

For more detailed information about local development, please read the [LOCAL-DEVELOPMENT.md](./LOCAL-DEVELOPMENT.md) file.
