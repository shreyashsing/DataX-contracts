// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

// Interface for DataNFT (updated to match DataNFT.mintNFT)
interface IDataNFT {
    function mintNFT(
        string calldata metadataURI,
        string calldata datasetCID,
        bytes32 datasetHash,
        bool isPrivate,
        bytes32 decryptionKey,
        address recipient
    ) external returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
}

// Enhanced AI Verification contract
contract AIVerification is AccessControl {
    // Role identifier for verifiers
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

    // Address of the associated DataNFT contract
    address public immutable dataNFTContract;

    // Struct to group verification input parameters to avoid stack too deep errors
    struct VerificationInput {
        bytes32 datasetHash;
        bytes32 verificationHash;
        bool isVerified;
        uint256 qualityScore;
        uint256 anomalies;
        uint256 duplicates;
        uint256 diversity;
        uint256 biasScore;
        string datasetCID;
        string analysisReport;
        bool isPrivate;
        bytes32 decryptionKey;
    }

    // Struct to store detailed verification results
    struct Verification {
        bytes32 verificationHash; // Hash of the AI analysis result
        bool isVerified;         // True if dataset passes AI checks
        uint256 timestamp;       // When the verification was recorded
        uint256 qualityScore;    // AI-assigned score (0-100)
        uint256 anomalies;       // Number of detected anomalies
        uint256 duplicates;      // Number of duplicate rows
        uint256 diversity;       // Diversity score (scaled to 0-100)
        uint256 biasScore;       // Bias score (scaled to 0-100)
        string datasetCID;       // IPFS CID of the dataset file
        string analysisReport;   // IPFS URI to the full report
        uint256 version;         // Verification version (for re-verifications)
    }

    // Custom errors
    error InvalidDatasetHash();
    error InvalidVerificationHash();
    error ScoreOutOfRange();
    error EmptyCID();
    error EmptyAnalysisReport();
    error InvalidURIFormat();
    error VerificationDoesNotExist();
    error NotAuthorized();

    // Mapping: datasetHash => version => Verification
    mapping(bytes32 => mapping(uint256 => Verification)) public verifications;
    // Mapping: datasetHash => latest version number
    mapping(bytes32 => uint256) public latestVersion;

    // Events for transparency and off-chain indexing
    event DatasetVerified(
        bytes32 indexed datasetHash,
        uint256 indexed version,
        bytes32 verificationHash,
        bool isVerified,
        uint256 timestamp,
        uint256 qualityScore,
        uint256 anomalies,
        uint256 duplicates,
        uint256 diversity,
        uint256 biasScore,
        string datasetCID,
        string analysisReport,
        uint256 tokenId
    );
    event DataNFTContractSet(address indexed dataNFTContract);
    event VerifierAdded(address indexed verifier);
    event VerifierRemoved(address indexed verifier);

    // Constructor: Initialize with DataNFT contract and set up roles
    constructor(address _dataNFTContract) {
        if (_dataNFTContract == address(0)) revert NotAuthorized();
        dataNFTContract = _dataNFTContract;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); // Contract deployer is admin
        _setupRole(VERIFIER_ROLE, msg.sender);     // Deployer can also verify
        emit DataNFTContractSet(_dataNFTContract);
    }

    // Modifier to restrict functions to verifiers or admins
    modifier onlyVerifier() {
        if (!hasRole(VERIFIER_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender))
            revert NotAuthorized();
        _;
    }

    // Add a new verifier (only admin)
    function addVerifier(address verifier) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (verifier == address(0)) revert NotAuthorized();
        grantRole(VERIFIER_ROLE, verifier);
        emit VerifierAdded(verifier);
    }

    // Remove a verifier (only admin)
    function removeVerifier(address verifier) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (verifier == address(0)) revert NotAuthorized();
        revokeRole(VERIFIER_ROLE, verifier);
        emit VerifierRemoved(verifier);
    }

    // Submit AI verification results for a dataset (verifiers or admins)
    // Using struct to avoid stack too deep error
    function verifyDataset(VerificationInput calldata input) external onlyVerifier {
        // Input validation
        if (input.datasetHash == bytes32(0)) revert InvalidDatasetHash();
        if (input.verificationHash == bytes32(0)) revert InvalidVerificationHash();
        if (input.qualityScore > 100) revert ScoreOutOfRange();
        if (input.diversity > 100) revert ScoreOutOfRange();
        if (input.biasScore > 100) revert ScoreOutOfRange();
        if (bytes(input.datasetCID).length == 0) revert EmptyCID();
        if (bytes(input.analysisReport).length == 0) revert EmptyAnalysisReport();
        
        // Validate IPFS URI format
        if (!_startsWith(input.datasetCID, "ipfs://")) revert InvalidURIFormat();
        if (!_startsWith(input.analysisReport, "ipfs://")) revert InvalidURIFormat();

        // Increment version for this dataset
        uint256 newVersion = latestVersion[input.datasetHash] + 1;
        latestVersion[input.datasetHash] = newVersion;

        // Store verification details
        verifications[input.datasetHash][newVersion] = Verification({
            verificationHash: input.verificationHash,
            isVerified: input.isVerified,
            timestamp: block.timestamp,
            qualityScore: input.qualityScore,
            anomalies: input.anomalies,
            duplicates: input.duplicates,
            diversity: input.diversity,
            biasScore: input.biasScore,
            datasetCID: input.datasetCID,
            analysisReport: input.analysisReport,
            version: newVersion
        });

        // Mint NFT if verified
        uint256 tokenId = 0;
        if (input.isVerified) {
            // Create metadata URI
            string memory tokenURI = generateMetadataURI(
                input.datasetHash,
                input.datasetCID,
                input.analysisReport
            );
            
            // Try to mint the NFT
            try IDataNFT(dataNFTContract).mintNFT(
                tokenURI,
                input.datasetCID,
                input.datasetHash,
                input.isPrivate,
                input.decryptionKey,
                msg.sender
            ) returns (uint256 newTokenId) {
                tokenId = newTokenId;
            } catch {
                // Log failure but don't revert
                emit DatasetVerified(
                    input.datasetHash,
                    newVersion,
                    input.verificationHash,
                    input.isVerified,
                    block.timestamp,
                    input.qualityScore,
                    input.anomalies,
                    input.duplicates,
                    input.diversity,
                    input.biasScore,
                    input.datasetCID,
                    input.analysisReport,
                    0
                );
                return;
            }
        }

        // Emit event with all verification details
        emit DatasetVerified(
            input.datasetHash,
            newVersion,
            input.verificationHash,
            input.isVerified,
            block.timestamp,
            input.qualityScore,
            input.anomalies,
            input.duplicates,
            input.diversity,
            input.biasScore,
            input.datasetCID,
            input.analysisReport,
            tokenId
        );
    }

    // Check if a dataset is verified (latest version)
    function isDatasetVerified(bytes32 datasetHash) external view returns (bool) {
        uint256 latestVer = latestVersion[datasetHash];
        if (latestVer == 0) return false;
        return verifications[datasetHash][latestVer].isVerified;
    }

    // Get verification details for a specific version
    function getVerification(bytes32 datasetHash, uint256 version)
        external
        view
        returns (Verification memory)
    {
        Verification memory v = verifications[datasetHash][version];
        if (v.timestamp == 0) revert VerificationDoesNotExist();
        return v;
    }

    // Get latest verification details
    function getLatestVerification(bytes32 datasetHash)
        external
        view
        returns (Verification memory)
    {
        uint256 latestVer = latestVersion[datasetHash];
        if (latestVer == 0) revert VerificationDoesNotExist();
        return verifications[datasetHash][latestVer];
    }

    // Get the latest version number for a dataset
    function getLatestVersion(bytes32 datasetHash) external view returns (uint256) {
        return latestVersion[datasetHash];
    }

    // Helper function to generate metadata URI (customizable)
    function generateMetadataURI(
        bytes32 datasetHash,
        string memory datasetCID,
        string memory analysisReport
    ) internal pure returns (string memory) {
        // Ideally, this should point to a JSON metadata file on IPFS
        // For simplicity, use analysisReport as base and append dataset info
        return string(
            abi.encodePacked(
                analysisReport,
                "?datasetHash=",
                Strings.toHexString(uint256(datasetHash)),
                "&datasetCID=",
                datasetCID
            )
        );
    }

    // Helper function to check if a string starts with a prefix
    function _startsWith(string memory str, string memory prefix) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory prefixBytes = bytes(prefix);
        if (strBytes.length < prefixBytes.length) return false;
        for (uint256 i = 0; i < prefixBytes.length; i++) {
            if (strBytes[i] != prefixBytes[i]) return false;
        }
        return true;
    }
}
