// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract DataNFT is ERC721, ERC721URIStorage, Ownable, ReentrancyGuard {
    uint256 private _tokenIds;
    address public aiVerificationContract;

    // Mapping from NFT ID to Datatoken address (ERC20)
    mapping(uint256 => address) public datatokens;
    // Mapping from NFT ID to IPFS CID of dataset
    mapping(uint256 => string) public datasetCIDs;
    // Mapping from NFT ID to decryption key (for private datasets)
    mapping(uint256 => bytes32) private decryptionKeys;
    // Mapping from NFT ID to authorized access addresses
    mapping(uint256 => mapping(address => bool)) private authorizedAccess;

    // Marketplace listings
    struct Listing {
        uint256 price; // Price in DataTokens
        bool isActive;
    }
    mapping(uint256 => Listing) public listings;

    event DataNFTMinted(uint256 indexed tokenId, string tokenURI, string datasetCID, address owner, bytes32 datasetHash);
    event DatatokenLinked(uint256 indexed tokenId, address datatoken);
    event NFTListed(uint256 indexed tokenId, uint256 price);
    event NFTSold(uint256 indexed tokenId, address buyer, uint256 price);
    event DataAccessed(uint256 indexed tokenId, address accessor, string datasetCID);
    event ListingPriceUpdated(uint256 indexed tokenId, uint256 newPrice);
    event AIVerificationContractSet(address indexed aiVerificationContract);
    event DatasetCIDUpdated(uint256 indexed tokenId, string newCID);
    event DecryptionKeySet(uint256 indexed tokenId, bytes32 decryptionKey);
    event AccessGranted(uint256 indexed tokenId, address user);

    // Custom errors for gas efficiency
    error InvalidNFT();
    error NotTheOwner();
    error NotAuthorized();
    error NoDatatokenLinked();
    error InsufficientPayment();
    error NotForSale();
    error TransferFailed();
    error InvalidDatasetCID();

    constructor() ERC721("DataNFT", "DNFT") {}

    // Set the AIVerification contract address (only owner)
    function setAIVerificationContract(address _aiVerificationContract) external onlyOwner {
        if (_aiVerificationContract == address(0)) revert NotAuthorized();
        aiVerificationContract = _aiVerificationContract;
        emit AIVerificationContractSet(_aiVerificationContract);
    }

    // Mint a new DataNFT with metadata, IPFS CID, and AI verification
    function mintNFT(
        string memory metadataURI,
        string memory datasetCID,
        bytes32 datasetHash,
        bool isPrivate,
        bytes32 decryptionKey,
        address recipient
    ) external onlyOwner returns (uint256) {
        if (aiVerificationContract == address(0)) revert NotAuthorized();
        if (!IAIVerification(aiVerificationContract).isDatasetVerified(datasetHash))
            revert NotAuthorized();

        uint256 newTokenId = _tokenIds + 1;
        _tokenIds = newTokenId;
        _safeMint(recipient, newTokenId);
        _setTokenURI(newTokenId, metadataURI);
        datasetCIDs[newTokenId] = datasetCID;
        
        // Grant access to the owner automatically
        authorizedAccess[newTokenId][recipient] = true;
        
        if (isPrivate) {
            decryptionKeys[newTokenId] = decryptionKey;
            emit DecryptionKeySet(newTokenId, decryptionKey);
        }
        emit DataNFTMinted(newTokenId, metadataURI, datasetCID, recipient, datasetHash);
        return newTokenId;
    }

    // Link a Datatoken to an NFT
    function linkDatatoken(uint256 tokenId, address datatokenAddress) external onlyOwner {
        if (!_exists(tokenId)) revert InvalidNFT();
        if (datatokens[tokenId] != address(0)) revert("Datatoken already linked");
        
        // Verify the datatokenAddress is a valid contract
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(datatokenAddress)
        }
        if (codeSize == 0) revert("Not a valid contract");
        
        datatokens[tokenId] = datatokenAddress;
        emit DatatokenLinked(tokenId, datatokenAddress);
    }

    // List an NFT for sale
    function listNFT(uint256 tokenId, uint256 priceInTokens) external {
        if (ownerOf(tokenId) != msg.sender) revert NotTheOwner();
        if (datatokens[tokenId] == address(0)) revert NoDatatokenLinked();
        
        listings[tokenId] = Listing(priceInTokens, true);
        approve(address(this), tokenId); // Allow contract to transfer NFT
        emit NFTListed(tokenId, priceInTokens);
    }

    // Update listing price
    function updateListingPrice(uint256 tokenId, uint256 newPrice) external {
        if (ownerOf(tokenId) != msg.sender) revert NotTheOwner();
        if (!listings[tokenId].isActive) revert NotForSale();
        
        listings[tokenId].price = newPrice;
        emit ListingPriceUpdated(tokenId, newPrice);
    }

    // Buy a listed NFT with balance check
    function buyNFT(uint256 tokenId) external nonReentrant {
        Listing memory listing = listings[tokenId];
        if (!listing.isActive) revert NotForSale();
        
        address seller = ownerOf(tokenId);
        address datatoken = datatokens[tokenId];
        uint256 price = listing.price;
        
        if (IERC20(datatoken).balanceOf(msg.sender) < price) revert InsufficientPayment();
        
        // Save state changes first to prevent reentrancy
        delete listings[tokenId];
        
        // Grant access to the new owner
        authorizedAccess[tokenId][msg.sender] = true;
        emit AccessGranted(tokenId, msg.sender);
        
        // Perform the external calls last
        if (!IERC20(datatoken).transferFrom(msg.sender, seller, price)) revert TransferFailed();
        _transfer(seller, msg.sender, tokenId);
        
        emit NFTSold(tokenId, msg.sender, price);
    }

    // Access data (requires ownership or payment)
    function accessData(uint256 tokenId, uint256 tokenAmount) external nonReentrant returns (string memory, bytes32) {
        if (!_exists(tokenId)) revert InvalidNFT();
        address datatoken = datatokens[tokenId];
        if (datatoken == address(0)) revert NoDatatokenLinked();
        
        // Check if access is authorized
        if (ownerOf(tokenId) != msg.sender && !authorizedAccess[tokenId][msg.sender]) {
            if (tokenAmount == 0) revert InsufficientPayment();
            
            // Save state changes first
            authorizedAccess[tokenId][msg.sender] = true;
            emit AccessGranted(tokenId, msg.sender);
            
            // Then perform the external call
            if (!IERC20(datatoken).transferFrom(msg.sender, ownerOf(tokenId), tokenAmount))
                revert TransferFailed();
        }
        
        string memory cid = datasetCIDs[tokenId];
        if (bytes(cid).length == 0) revert InvalidDatasetCID();
        
        bytes32 key = decryptionKeys[tokenId]; // Returns 0x0 if not private
        emit DataAccessed(tokenId, msg.sender, cid);
        return (cid, key);
    }

    // Check if an address has access to a dataset
    function hasAccess(uint256 tokenId, address user) external view returns (bool) {
        if (!_exists(tokenId)) revert InvalidNFT();
        return ownerOf(tokenId) == user || authorizedAccess[tokenId][user];
    }

    // Update dataset CID (e.g., if file is moved or updated)
    function updateDatasetCID(uint256 tokenId, string memory newCID) external onlyOwner {
        if (!_exists(tokenId)) revert InvalidNFT();
        if (bytes(newCID).length == 0) revert InvalidDatasetCID();
        
        datasetCIDs[tokenId] = newCID;
        emit DatasetCIDUpdated(tokenId, newCID);
    }

    // Get Datatoken address for an NFT
    function getDatatoken(uint256 tokenId) external view returns (address) {
        if (!_exists(tokenId)) revert InvalidNFT();
        return datatokens[tokenId];
    }

    // Burn an NFT
    function burnNFT(uint256 tokenId) external onlyOwner {
        if (!_exists(tokenId)) revert InvalidNFT();
        _burn(tokenId);
        delete datatokens[tokenId];
        delete listings[tokenId];
        delete datasetCIDs[tokenId];
        delete decryptionKeys[tokenId];
    }

    // Override for ERC721URIStorage
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    // Updated tokenURI with minimum DataToken requirement
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        if (!_exists(tokenId)) revert InvalidNFT();
        
        address datatoken = datatokens[tokenId];
        if (datatoken != address(0)) {
            if (IERC20(datatoken).balanceOf(msg.sender) < 1 * 10**18 && ownerOf(tokenId) != msg.sender)
                revert NotAuthorized();
        }
        return super.tokenURI(tokenId);
    }
}

// Interface for AIVerification contract
interface IAIVerification {
    function isDatasetVerified(bytes32 datasetHash) external view returns (bool);
}

// Interface for DataNFT (updated to include isApprovedForAll and getApproved)
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
    function transferFrom(address from, address to, uint256 tokenId) external;
    function datasetCIDs(uint256 tokenId) external view returns (string memory);
    function accessData(uint256 tokenId, uint256 tokenAmount) external returns (string memory, bytes32);
    function getDatatoken(uint256 tokenId) external view returns (address);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
    function getApproved(uint256 tokenId) external view returns (address);
    function hasAccess(uint256 tokenId, address user) external view returns (bool);
}
