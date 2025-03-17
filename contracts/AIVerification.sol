// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract AIVerification is Ownable {
    // Address of the associated DataNFT contract
    address public dataNFTContract;

    // Struct to store verification details for each dataset
    struct Verification {
        bytes32 verificationHash; // Hash of the AI analysis result
        bool isVerified;         // True if the dataset passes AI checks
        uint256 timestamp;       // When the verification was recorded
        uint256 qualityScore;    // AI-assigned score (0-100)
        string analysisReport;   // URI (e.g., IPFS link) to the full report
    }

    // Mapping from dataset hash to its verification details
    mapping(bytes32 => Verification) public verifications;

    // Events for transparency and tracking
    event DatasetVerified(
        bytes32 indexed datasetHash,
        bytes32 verificationHash,
        bool isVerified,
        uint256 timestamp,
        uint256 qualityScore,
        string analysisReport
    );
    event DataNFTContractSet(address indexed dataNFTContract);

    // Constructor to initialize with the DataNFT contract address
    constructor(address _dataNFTContract) {
        dataNFTContract = _dataNFTContract;
        emit DataNFTContractSet(_dataNFTContract);
    }

    // Set or update the DataNFT contract address (only owner)
    function setDataNFTContract(address _dataNFTContract) external onlyOwner {
        dataNFTContract = _dataNFTContract;
        emit DataNFTContractSet(_dataNFTContract);
    }

    // Submit AI verification results for a dataset (only owner)
    function verifyDataset(
        bytes32 datasetHash,
        bytes32 verificationHash,
        bool isVerified,
        uint256 qualityScore,
        string calldata analysisReport
    ) external onlyOwner {
        require(verifications[datasetHash].timestamp == 0, "Dataset already verified");
        require(qualityScore <= 100, "Quality score must be 0-100");

        verifications[datasetHash] = Verification({
            verificationHash: verificationHash,
            isVerified: isVerified,
            timestamp: block.timestamp,
            qualityScore: qualityScore,
            analysisReport: analysisReport
        });

        emit DatasetVerified(
            datasetHash,
            verificationHash,
            isVerified,
            block.timestamp,
            qualityScore,
            analysisReport
        );
    }

    // Check if a dataset is verified
    function isDatasetVerified(bytes32 datasetHash) external view returns (bool) {
        return verifications[datasetHash].isVerified;
    }

    // Get full verification details for a dataset
    function getVerification(bytes32 datasetHash)
        external
        view
        returns (
            bytes32 verificationHash,
            bool isVerified,
            uint256 timestamp,
            uint256 qualityScore,
            string memory analysisReport
        )
    {
        Verification memory v = verifications[datasetHash];
        return (v.verificationHash, v.isVerified, v.timestamp, v.qualityScore, v.analysisReport);
    }
}

// Interface for DataNFT (minimal, for reference)
interface IDataNFT {
    function mintNFT(string calldata tokenURI, bytes32 datasetHash) external returns (uint256);
}