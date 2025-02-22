// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DataNFT is ERC721, ERC721URIStorage, Ownable {
    uint256 private _tokenIds;

    // Mapping from NFT ID to Datatoken address (ERC20)
    mapping(uint256 => address) public datatokens;

    // Marketplace listings
    struct Listing {
        uint256 price; // Price in DataTokens
        bool isActive;
    }
    mapping(uint256 => Listing) public listings;

    event DataNFTMinted(uint256 indexed tokenId, string tokenURI, address owner);
    event DatatokenLinked(uint256 indexed tokenId, address datatoken);
    event NFTListed(uint256 indexed tokenId, uint256 price);
    event NFTSold(uint256 indexed tokenId, address buyer, uint256 price);
    event DataAccessed(uint256 indexed tokenId, address accessor);

    constructor() ERC721("DataNFT", "DNFT") {}

    // Mint a new DataNFT with metadata
    function mintNFT(string memory tokenURI) external onlyOwner returns (uint256) {
        uint256 newTokenId = _tokenIds + 1;
        _tokenIds = newTokenId;
        _safeMint(msg.sender, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
        emit DataNFTMinted(newTokenId, tokenURI, msg.sender);
        return newTokenId;
    }

    // Link a Datatoken to an NFT
    function linkDatatoken(uint256 tokenId, address datatokenAddress) external onlyOwner {
        require(_exists(tokenId), "NFT does not exist");
        require(datatokens[tokenId] == address(0), "Datatoken already linked");
        datatokens[tokenId] = datatokenAddress;
        emit DatatokenLinked(tokenId, datatokenAddress);
    }

    // List an NFT for sale
    function listNFT(uint256 tokenId, uint256 priceInTokens) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        require(datatokens[tokenId] != address(0), "No DataToken linked");
        listings[tokenId] = Listing(priceInTokens, true);
        approve(address(this), tokenId); // Allow contract to transfer NFT
        emit NFTListed(tokenId, priceInTokens);
    }

    // Buy a listed NFT
    function buyNFT(uint256 tokenId) external {
        Listing memory listing = listings[tokenId];
        require(listing.isActive, "Not listed");
        address seller = ownerOf(tokenId);
        address datatoken = datatokens[tokenId];
        uint256 price = listing.price;
        require(IERC20(datatoken).transferFrom(msg.sender, seller, price), "Transfer failed");
        _transfer(seller, msg.sender, tokenId);
        delete listings[tokenId];
        emit NFTSold(tokenId, msg.sender, price);
    }

    // Access data (requires ownership or payment)
    function accessData(uint256 tokenId, uint256 tokenAmount) external {
        require(_exists(tokenId), "NFT does not exist");
        address datatoken = datatokens[tokenId];
        require(datatoken != address(0), "No DataToken linked");
        if (ownerOf(tokenId) != msg.sender) {
            require(tokenAmount > 0, "Payment required");
            require(IERC20(datatoken).transferFrom(msg.sender, ownerOf(tokenId), tokenAmount), "Payment failed");
        }
        emit DataAccessed(tokenId, msg.sender);
        // Off-chain systems can use the event to grant access
    }

    // Get Datatoken address for an NFT
    function getDatatoken(uint256 tokenId) external view returns (address) {
        require(_exists(tokenId), "NFT does not exist");
        return datatokens[tokenId];
    }

    // Burn an NFT
    function burnNFT(uint256 tokenId) external onlyOwner {
        require(_exists(tokenId), "NFT does not exist");
        _burn(tokenId);
        delete datatokens[tokenId];
        delete listings[tokenId];
    }

    // Override for ERC721URIStorage
    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    // Restrict tokenURI to owners or DataToken holders
    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        require(_exists(tokenId), "NFT does not exist");
        address datatoken = datatokens[tokenId];
        if (datatoken != address(0)) {
            require(
                IERC20(datatoken).balanceOf(msg.sender) > 0 || ownerOf(tokenId) == msg.sender,
                "No access rights"
            );
        }
        return super.tokenURI(tokenId);
    }
}