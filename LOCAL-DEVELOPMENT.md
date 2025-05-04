# Local Development Guide for DataX Contracts

This guide explains how to test your DataX contracts using a local Hardhat network, eliminating the need for testnet tokens.

## Benefits of Local Development

- **No real tokens needed**: You get unlimited test ETH and can create mock LINK tokens
- **Fast development**: No waiting for testnet confirmations
- **Complete control**: Reset the blockchain state anytime
- **Free testing**: No costs for gas fees or test tokens

## Setup Local Development Environment

### Step 1: Install Dependencies

Make sure all dependencies are installed:

```bash
cd Contracts
npm install
```

### Step 2: Start a Local Hardhat Node

Open a terminal and start the local Hardhat network:

```bash
npx hardhat node
```

This will start a local blockchain on `http://127.0.0.1:8545/` with several funded accounts. Keep this terminal running throughout your development process.

### Step 3: Deploy Your Contracts

In a new terminal, deploy your contracts to the local network:

```bash
npx hardhat run scripts/deploy-local.js --network localhost
```

This script will:
1. Deploy a mock LINK token contract
2. Mint 1000 mock LINK tokens to your account
3. Deploy all the DataX contracts (DataNFT, AIVerification, Marketplace)
4. Configure the contracts to work with each other
5. Save the deployment information to `deployment-local.json`

### Step 4: Test Interactions

Run the interaction script to test the complete workflow:

```bash
npx hardhat run scripts/interact-local.js --network localhost
```

This script demonstrates:
1. Transferring LINK tokens between accounts
2. Verifying a dataset through AIVerification
3. Minting a DataNFT
4. Listing the DataNFT for sale
5. Another user buying the DataNFT with LINK tokens

## Understanding the Local Environment

### Mock LINK Token

We've created a `MockLINK.sol` contract that simulates the LINK token on testnet. This token has a `mint` function that allows you to create unlimited tokens for testing.

### Test Accounts

Hardhat provides 20 test accounts, each funded with 10,000 ETH. You can use these accounts to simulate different users in your application. The deploy script uses the first account as the deployer and contract owner.

## Advanced Usage

### Resetting the Local Blockchain

If you want to start fresh, you can:

1. Stop the running Hardhat node (Ctrl+C)
2. Start it again: `npx hardhat node`
3. Redeploy your contracts

### Custom Test Scenarios

You can create custom test scripts by following the pattern in `interact-local.js`. For example:

```javascript
// scripts/custom-test.js
const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
  // Load deployment information
  const deployment = JSON.parse(fs.readFileSync("deployment-local.json", "utf8"));
  
  // Get contracts
  const mockLink = await ethers.getContractAt("MockLINK", deployment.linkToken);
  const dataNFT = await ethers.getContractAt("DataNFT", deployment.dataNFT);
  
  // Your custom test code here
  // ...
}

main().catch(console.error);
```

### Testing Frontend Integration

You can connect your web frontend to the local Hardhat network using:

- Network URL: `http://127.0.0.1:8545/`
- Chain ID: `31337`

## Migrating to Testnet

Once your contracts work correctly on the local network, you can deploy to a testnet:

1. Get testnet tokens from a faucet
2. Update your deployment scripts to use the appropriate testnet configuration
3. Deploy using the testnet network configuration in your hardhat.config.js file

## Troubleshooting

### Error: Cannot find deployment-local.json

Make sure you've run the deployment script first:

```bash
npx hardhat run scripts/deploy-local.js --network localhost
```

### Error: Transaction reverted

Check that:
1. Your Hardhat node is still running
2. You're using the correct contract addresses from the deployment file
3. The account you're using has sufficient funds

### Error: Contract not deployed to the detected network

Make sure you're connecting to the correct network (localhost) in your scripts. 