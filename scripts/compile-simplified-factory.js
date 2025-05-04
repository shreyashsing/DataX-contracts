// Script to compile the SimplifiedTokenFactory contract and extract its bytecode
const fs = require('fs');
const path = require('path');

// Paths
const contractsPath = path.join(__dirname, '..');
const artifactsPath = path.join(contractsPath, 'artifacts', 'contracts', 'SimplifiedTokenFactory.sol', 'SimplifiedTokenFactory.json');
const outputPath = path.join(__dirname, '..', '..', 'DataX-WebApplication', 'lib', 'contracts', 'bytecode', 'SimplifiedTokenFactory.js');

// Ensure output directory exists
const outputDir = path.dirname(outputPath);
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

try {
  // Read compiled contract artifacts
  if (!fs.existsSync(artifactsPath)) {
    console.error('SimplifiedTokenFactory contract artifacts not found.');
    console.error('Make sure to compile the contracts first with: npx hardhat compile');
    process.exit(1);
  }

  const artifact = JSON.parse(fs.readFileSync(artifactsPath, 'utf8'));
  const bytecode = artifact.bytecode;

  if (!bytecode || !bytecode.startsWith('0x')) {
    console.error('Invalid bytecode format in artifacts.');
    process.exit(1);
  }

  // Create JS file with bytecode and ABI
  const content = `// Auto-generated from SimplifiedTokenFactory contract compilation
// This file contains the bytecode and ABI of the SimplifiedTokenFactory contract

export const SimplifiedTokenFactoryBytecode = "${bytecode}";

export const SimplifiedTokenFactoryAbi = ${JSON.stringify(artifact.abi, null, 2)};

// Add default export for easier importing
export default {
  SimplifiedTokenFactoryBytecode,
  SimplifiedTokenFactoryAbi
};
`;

  fs.writeFileSync(outputPath, content);
  console.log(`SimplifiedTokenFactory bytecode and ABI written to: ${outputPath}`);
} catch (error) {
  console.error('Error processing contract bytecode:', error);
  process.exit(1);
} 