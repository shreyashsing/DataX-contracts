// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./DataNFT.sol";

contract DataToken is ERC20, Ownable, ReentrancyGuard {
    uint256 public initialSupply;
    uint256 public tokenPrice; // Price of 1 DataToken in wei
    uint256 public maxSupply;  // Maximum supply limit
    uint8 private immutable _decimals;

    // Associated NFT contract
    address public associatedNFTContract;
    uint256 public associatedNFTId;

    // Custom errors
    error NoNFTLinked();
    error NFTAlreadyLinked();
    error InvalidNFTContract();
    error NFTNotLinked();
    error MaxSupplyExceeded();
    error InsufficientEther();
    error InsufficientTokens();
    error InvalidCID();
    error RefundFailed();
    error WithdrawalFailed();
    error NoEtherToWithdraw();
    error TransferFailed();

    event DataTokenMinted(uint256 amount, address owner);
    event TokenPriceUpdated(uint256 newPrice);
    event NFTLinked(uint256 tokenId, address nftContract);
    event DataAccessRedeemed(uint256 indexed nftId, address user, string datasetCID);
    event EtherWithdrawn(address indexed owner, uint256 amount);

    constructor(
        string memory name,
        string memory symbol,
        uint256 _initialSupply,
        uint256 _tokenPrice,
        uint8 decimalsValue
    ) ERC20(name, symbol) {
        _decimals = decimalsValue;
        maxSupply = 1_000_000 * (10 ** _decimals); // Set to 1 million tokens by default
        
        if (_initialSupply > maxSupply) revert MaxSupplyExceeded();
        
        initialSupply = _initialSupply;
        tokenPrice = _tokenPrice;
        _mint(msg.sender, _initialSupply);
        emit DataTokenMinted(_initialSupply, msg.sender);
    }

    /**
     * @dev Override decimals to use custom value instead of default 18
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    // Link an NFT to this DataToken
    function setAssociatedNFT(address nftContract, uint256 tokenId) external onlyOwner {
        if (associatedNFTContract != address(0)) revert NFTAlreadyLinked();
        if (nftContract == address(0)) revert InvalidNFTContract();
        
        // Verify the nftContract is an actual contract
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(nftContract)
        }
        if (codeSize == 0) revert InvalidNFTContract();
        
        // Verify the NFT exists and that this token is linked to it
        try IDataNFT(nftContract).getDatatoken(tokenId) returns (address linkedToken) {
            if (linkedToken != address(this)) revert NFTNotLinked();
            
            try IDataNFT(nftContract).ownerOf(tokenId) returns (address) {
                // NFT exists and is linked to this token
                associatedNFTContract = nftContract;
                associatedNFTId = tokenId;
                emit NFTLinked(tokenId, nftContract);
            } catch {
                revert NFTNotLinked();
            }
        } catch {
            revert NFTNotLinked();
        }
    }

    // Buy tokens with Ether, respecting max supply
    function buyTokens(uint256 tokenAmount) external payable nonReentrant {
        uint256 cost = (tokenAmount * tokenPrice) / (10 ** _decimals);
        
        if (totalSupply() + tokenAmount > maxSupply) revert MaxSupplyExceeded();
        if (msg.value < cost) revert InsufficientEther();

        _mint(msg.sender, tokenAmount);

        if (msg.value > cost) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - cost}("");
            if (!success) revert RefundFailed();
        }
    }

    // Withdraw accumulated Ether
    function withdrawEther() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoEtherToWithdraw();
        
        (bool success, ) = payable(owner()).call{value: balance}("");
        if (!success) revert WithdrawalFailed();
        
        emit EtherWithdrawn(owner(), balance);
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

    // Set max supply (owner only)
    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        if (newMaxSupply < totalSupply()) revert MaxSupplyExceeded();
        maxSupply = newMaxSupply;
    }

    // Redeem tokens for NFT data access
    function redeemForAccess(uint256 amount, uint256 nftId) external nonReentrant returns (string memory, bytes32) {
        if (balanceOf(msg.sender) < amount) revert InsufficientTokens();
        
        if (associatedNFTContract == address(0)) revert NoNFTLinked();
        
        // First check if the NFT is linked to this token
        address linkedToken;
        try IDataNFT(associatedNFTContract).getDatatoken(nftId) returns (address token) {
            linkedToken = token;
        } catch {
            revert NFTNotLinked();
        }
        
        if (linkedToken != address(this)) revert NFTNotLinked();
        
        // Get the NFT owner
        address nftOwner;
        try IDataNFT(associatedNFTContract).ownerOf(nftId) returns (address owner) {
            nftOwner = owner;
        } catch {
            revert NFTNotLinked();
        }
        
        // Transfer tokens before external call to prevent reentrancy
        _transfer(msg.sender, nftOwner, amount);
        
        // Call DataNFT.accessData to get IPFS CID and decryption key
        string memory datasetCID;
        bytes32 decryptionKey;
        
        try IDataNFT(associatedNFTContract).accessData(nftId, 0) returns (string memory cid, bytes32 key) {
            datasetCID = cid;
            decryptionKey = key;
        } catch {
            revert NFTNotLinked();
        }
        
        if (bytes(datasetCID).length == 0) revert InvalidCID();

        emit DataAccessRedeemed(nftId, msg.sender, datasetCID);
        return (datasetCID, decryptionKey);
    }

    // Override transfer to ensure token tracking
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._beforeTokenTransfer(from, to, amount);
    }
}
