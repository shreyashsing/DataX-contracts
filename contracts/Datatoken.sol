// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DataToken is ERC20, Ownable {
    uint256 public initialSupply;
    uint256 public tokenPrice; // Price of 1 DataToken in Ether (wei)
    uint256 public maxSupply = 1_000_000 * 10**18; // Maximum supply limit (1M tokens)

    // Mapping of associated NFTs (tokenId => isLinked)
    address public associatedNFTContract;
    mapping(uint256 => bool) public linkedNFTs;

    event DataTokenMinted(uint256 amount, address owner);
    event TokenPriceUpdated(uint256 newPrice);
    event NFTLinked(uint256 tokenId, address nftContract);

    constructor(
        string memory name,
        string memory symbol,
        uint256 _initialSupply,
        uint256 _tokenPrice
    ) ERC20(name, symbol) {
        require(_initialSupply <= maxSupply, "Initial supply exceeds max supply");
        initialSupply = _initialSupply;
        tokenPrice = _tokenPrice;
        _mint(msg.sender, _initialSupply);
        emit DataTokenMinted(_initialSupply, msg.sender);
    }

    // Link an NFT to this DataToken (one-time linking per contract)
    function setAssociatedNFT(address nftContract, uint256 tokenId) external onlyOwner {
        require(associatedNFTContract == address(0), "NFT contract already linked");
        associatedNFTContract = nftContract;
        linkedNFTs[tokenId] = true;
        emit NFTLinked(tokenId, nftContract);
    }

    // Buy tokens with Ether, respecting max supply
    function buyTokens(uint256 tokenAmount) external payable {
        uint256 cost = (tokenAmount * tokenPrice) / 1 ether;
        require(totalSupply() + tokenAmount <= maxSupply, "Exceeds max supply");
        require(msg.value >= cost, "Insufficient Ether");
        _mint(msg.sender, tokenAmount);
        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }
    }

    // Withdraw accumulated Ether
    function withdrawEther() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    // Update token price
    function updateTokenPrice(uint256 newPrice) external onlyOwner {
        tokenPrice = newPrice;
        emit TokenPriceUpdated(newPrice);
    }

    // Burn tokens (owner only)
    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }

    // Redeem tokens for NFT data access
    function redeemForAccess(uint256 amount, uint256 nftId) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient tokens");
        require(linkedNFTs[nftId], "NFT not linked");
        address nftOwner = IDataNFT(associatedNFTContract).ownerOf(nftId);
        _transfer(msg.sender, nftOwner, amount);
    }

    // Override transfer (no strict restrictions)
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
    }
}

// Interface for interacting with DataNFT
interface IDataNFT {
    function ownerOf(uint256 tokenId) external view returns (address);
}