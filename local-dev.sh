#!/bin/bash

# DataX Local Development Script

echo "DataX Local Development Environment"
echo "=================================="

# Check if another Hardhat node is running
if lsof -i:8545 > /dev/null; then
  echo "Error: Port 8545 is already in use."
  echo "If you have another Hardhat node running, please close it first."
  echo "If you want to proceed anyway, run the following commands manually:"
  echo "1. npx hardhat run scripts/deploy-local.js --network localhost"
  echo "2. npx hardhat run scripts/interact-local.js --network localhost"
  exit 1
fi

# Clean up any previous logs
rm -f hardhat-node.log

# Start Hardhat node in the background
echo "Starting local Hardhat node..."
npx hardhat node > hardhat-node.log 2>&1 &
HARDHAT_PID=$!

# Give it a moment to start up
sleep 3

echo "Hardhat node running on http://127.0.0.1:8545/ (PID: $HARDHAT_PID)"
echo "Log file: hardhat-node.log"

# Clean up on exit
function cleanup {
  echo "Stopping Hardhat node..."
  kill -9 $HARDHAT_PID
  echo "Done."
}
trap cleanup EXIT

# Deploy contracts
echo ""
echo "Deploying contracts to local network..."
npx hardhat run scripts/deploy-local.js --network localhost

# Prompt user to run interaction script
echo ""
echo "Contracts deployed successfully!"
read -p "Would you like to run the interaction script now? (y/n): " run_interact

if [ "$run_interact" = "y" ] || [ "$run_interact" = "Y" ]; then
  echo "Running interaction script..."
  npx hardhat run scripts/interact-local.js --network localhost
else
  echo "Skipping interaction script."
  echo "You can run it later with: npx hardhat run scripts/interact-local.js --network localhost"
fi

# Keep node running until user exits
echo ""
echo "Local Hardhat node is still running."
echo "Press Ctrl+C to stop the node and exit."
echo ""
echo "Available commands (run in another terminal):"
echo "- npx hardhat run scripts/interact-local.js --network localhost"
echo "- npx hardhat console --network localhost"

# Wait for user to exit
wait $HARDHAT_PID 