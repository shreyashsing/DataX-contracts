// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./SimplifiedDatatoken.sol";
import "./DataNFT.sol";

/**
 * @title SimplifiedTokenFactory
 * @dev A factory contract that creates and links SimplifiedDatatoken instances
 */
contract SimplifiedTokenFactory {
    // Reference to the DataNFT contract
    address public immutable dataNFTContract;
    
    // Events
    event TokenCreated(uint256 indexed tokenId, address tokenAddress);
    
    // Errors
    error FailedToCreateToken();
    error FailedToLinkToken();
    error NotNFTOwner();
    error InvalidNFT();
    
    /**
     * @dev Constructor - set the DataNFT contract
     * @param _dataNFTContract The DataNFT contract address
     */
    constructor(address _dataNFTContract) {
        dataNFTContract = _dataNFTContract;
    }
    
    /**
     * @dev Creates a new SimplifiedDatatoken for a DataNFT and links it
     * @param tokenId The NFT ID
     * @param name The token name
     * @param symbol The token symbol
     */
    function createToken(
        uint256 tokenId,
        string memory name,
        string memory symbol
    ) external returns (address) {
        // Check if caller is the owner of the NFT
        DataNFT nft = DataNFT(dataNFTContract);
        
        if (!_isNFTOwner(nft, tokenId, msg.sender)) {
            revert NotNFTOwner();
        }
        
        // Deploy a new SimplifiedDatatoken with minimal parameters
        SimplifiedDatatoken token = new SimplifiedDatatoken(name, symbol);
        
        // Link the token to the NFT
        try nft.linkDatatoken(tokenId, address(token)) {
            // Set the NFT association on the token
            try token.setAssociatedNFT(dataNFTContract, tokenId) {
                emit TokenCreated(tokenId, address(token));
                return address(token);
            } catch {
                revert FailedToCreateToken();
            }
        } catch {
            revert FailedToLinkToken();
        }
    }
    
    /**
     * @dev Check if an address is the owner of an NFT
     */
    function _isNFTOwner(DataNFT nft, uint256 tokenId, address account) internal view returns (bool) {
        try nft.ownerOf(tokenId) returns (address owner) {
            return owner == account;
        } catch {
            revert InvalidNFT();
        }
    }
} 