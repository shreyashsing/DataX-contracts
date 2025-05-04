// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./DataNFT.sol";

/**
 * @title SimplifiedDatatoken
 * @dev A simplified ERC20 token for DataX NFTs with minimal memory requirements
 */
contract SimplifiedDatatoken is ERC20, Ownable {
    // Associated NFT ID and contract
    address public associatedNFTContract;
    uint256 public associatedNFTId;
    
    // Token price in wei
    uint256 public tokenPrice = 0.01 ether;
    
    // Events
    event NFTLinked(uint256 tokenId, address nftContract);
    event TokenPriceUpdated(uint256 newPrice);
    
    /**
     * @dev Constructor - creates a new DataToken with minimal parameters
     * @param name Token name
     * @param symbol Token symbol 
     */
    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        // Mint initial supply to deployer (100,000 tokens)
        _mint(msg.sender, 100000 * (10 ** decimals()));
    }

    /**
     * @dev Set the associated NFT for this token
     * @param nftContract The NFT contract address
     * @param tokenId The NFT token ID
     */
    function setAssociatedNFT(address nftContract, uint256 tokenId) external onlyOwner {
        require(associatedNFTContract == address(0), "NFT already linked");
        require(nftContract != address(0), "Invalid NFT contract");
        
        // Verify the NFT exists and this token is linked to it
        IDataNFT nft = IDataNFT(nftContract);
        
        address linkedToken = nft.getDatatoken(tokenId);
        require(linkedToken == address(this), "Token not linked to NFT");
        
        // Save the association
        associatedNFTContract = nftContract;
        associatedNFTId = tokenId;
        
        emit NFTLinked(tokenId, nftContract);
    }
    
    /**
     * @dev Update token price
     * @param newPrice The new price in wei
     */
    function updateTokenPrice(uint256 newPrice) external onlyOwner {
        tokenPrice = newPrice;
        emit TokenPriceUpdated(newPrice);
    }

    /**
     * @dev Allow users to buy tokens with ETH
     */
    function buyTokens(uint256 amount) external payable {
        uint256 cost = amount * tokenPrice / (10 ** decimals());
        require(msg.value >= cost, "Insufficient ETH sent");
        
        // Mint tokens to buyer
        _mint(msg.sender, amount);
        
        // Refund excess ETH
        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }
    }
    
    /**
     * @dev Withdraw accumulated ETH (owner only)
     */
    function withdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        
        payable(owner()).transfer(balance);
    }
} 