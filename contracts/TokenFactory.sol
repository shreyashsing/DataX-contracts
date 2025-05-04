// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./Datatoken.sol";
import "./DataNFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TokenFactory
 * @dev Factory contract for creating and managing DataTokens linked to DataNFTs
 */
contract TokenFactory is Ownable {
    // The DataNFT contract address
    address public dataNFTContract;
    
    // Default token parameters
    uint256 public defaultInitialSupply = 1_000_000 * (10 ** 18); // 1 million tokens
    uint256 public defaultTokenPrice = 1e16; // 0.01 ETH per token
    uint8 public defaultDecimals = 18;
    
    // Mappings to store token information
    mapping(uint256 => address) public tokensByNFTId;
    
    // Events
    event DataTokenCreated(
        uint256 indexed nftId,
        address tokenAddress,
        string name,
        string symbol,
        uint256 initialSupply,
        address owner
    );
    event DefaultParametersChanged(
        uint256 initialSupply,
        uint256 tokenPrice,
        uint8 decimals
    );
    
    // Custom errors
    error InvalidNFTContract();
    error TokenAlreadyExists();
    error FailedToCreateToken();
    error NotNFTOwner();
    error NotNFTContract();
    
    /**
     * @dev Constructor initializes the factory with the DataNFT contract address
     * @param _dataNFTContract The address of the DataNFT contract
     */
    constructor(address _dataNFTContract) {
        if (_dataNFTContract == address(0)) revert InvalidNFTContract();
        dataNFTContract = _dataNFTContract;
    }
    
    /**
     * @dev Sets the DataNFT contract address
     * @param _dataNFTContract The address of the DataNFT contract
     */
    function setDataNFTContract(address _dataNFTContract) external onlyOwner {
        if (_dataNFTContract == address(0)) revert InvalidNFTContract();
        dataNFTContract = _dataNFTContract;
    }
    
    /**
     * @dev Sets the default token parameters
     * @param _initialSupply The default initial supply for new tokens
     * @param _tokenPrice The default token price in wei
     * @param _decimals The default number of decimals for the token
     */
    function setDefaultParameters(
        uint256 _initialSupply,
        uint256 _tokenPrice,
        uint8 _decimals
    ) external onlyOwner {
        defaultInitialSupply = _initialSupply;
        defaultTokenPrice = _tokenPrice;
        defaultDecimals = _decimals;
        
        emit DefaultParametersChanged(_initialSupply, _tokenPrice, _decimals);
    }
    
    /**
     * @dev Creates a new DataToken for an existing DataNFT
     * This function can only be called by the NFT owner
     * @param nftId The ID of the NFT to link the token to
     * @param name The name of the token
     * @param symbol The symbol of the token
     * @param initialSupply Optional custom initial supply (0 to use default)
     * @param tokenPrice Optional custom token price (0 to use default)
     * @param decimals Optional custom decimals (0 to use default)
     */
    function createToken(
        uint256 nftId,
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 tokenPrice,
        uint8 decimals
    ) external returns (address) {
        // Check if token already exists
        if (tokensByNFTId[nftId] != address(0)) revert TokenAlreadyExists();
        
        // Verify the caller is the owner of the NFT
        try DataNFT(dataNFTContract).ownerOf(nftId) returns (address nftOwner) {
            if (nftOwner != msg.sender) revert NotNFTOwner();
        } catch {
            revert InvalidNFTContract();
        }
        
        // Use default values if not specified
        if (initialSupply == 0) initialSupply = defaultInitialSupply;
        if (tokenPrice == 0) tokenPrice = defaultTokenPrice;
        if (decimals == 0) decimals = defaultDecimals;
        
        // Deploy new DataToken
        DataToken newToken = new DataToken(
            name,
            symbol,
            initialSupply,
            tokenPrice,
            decimals
        );
        
        // Transfer ownership to the NFT owner
        newToken.transferOwnership(msg.sender);
        
        // Save the token address
        address tokenAddress = address(newToken);
        tokensByNFTId[nftId] = tokenAddress;
        
        try DataNFT(dataNFTContract).linkDatatoken(nftId, tokenAddress) {
            // The token was successfully linked to the NFT
        } catch {
            revert FailedToCreateToken();
        }
        
        // Try to set the associated NFT in the token contract
        try DataToken(tokenAddress).setAssociatedNFT(dataNFTContract, nftId) {
            // The NFT was successfully linked to the token
        } catch {
            // This is not critical, so we don't revert
            // The owner can manually call setAssociatedNFT later
        }
        
        emit DataTokenCreated(
            nftId,
            tokenAddress,
            name,
            symbol,
            initialSupply,
            msg.sender
        );
        
        return tokenAddress;
    }
    
    /**
     * @dev Creates a token automatically when an NFT is minted
     * This function should be called only by the DataNFT contract
     * @param nftId The ID of the newly minted NFT
     * @param owner The owner of the NFT
     * @param datasetName The name of the dataset
     */
    function createTokenForNFT(
        uint256 nftId,
        address owner,
        string memory /* metadata */, // Commented out unused parameter
        string memory datasetName
    ) external returns (address) {
        // Ensure this is called by the DataNFT contract
        if (msg.sender != dataNFTContract) revert NotNFTContract();
        
        // Check if token already exists
        if (tokensByNFTId[nftId] != address(0)) revert TokenAlreadyExists();
        
        // Generate token name and symbol from the dataset name
        string memory tokenName = string(abi.encodePacked("DT-", datasetName));
        string memory tokenSymbol = _generateSymbol(datasetName);
        
        // Deploy new DataToken
        DataToken newToken = new DataToken(
            tokenName,
            tokenSymbol,
            defaultInitialSupply,
            defaultTokenPrice,
            defaultDecimals
        );
        
        // Transfer ownership to the NFT owner
        newToken.transferOwnership(owner);
        
        // Save the token address
        address tokenAddress = address(newToken);
        tokensByNFTId[nftId] = tokenAddress;
        
        try DataNFT(dataNFTContract).linkDatatoken(nftId, tokenAddress) {
            // The token was successfully linked to the NFT
        } catch {
            revert FailedToCreateToken();
        }
        
        // Try to set the associated NFT in the token contract
        try DataToken(tokenAddress).setAssociatedNFT(dataNFTContract, nftId) {
            // The NFT was successfully linked to the token
        } catch {
            // This is not critical, so we don't revert
            // The owner can manually call setAssociatedNFT later
        }
        
        emit DataTokenCreated(
            nftId,
            tokenAddress,
            tokenName,
            tokenSymbol,
            defaultInitialSupply,
            owner
        );
        
        return tokenAddress;
    }
    
    /**
     * @dev Helper function to generate a token symbol from a dataset name
     * @param name The name of the dataset
     * @return A 5-character token symbol
     */
    function _generateSymbol(string memory name) internal pure returns (string memory) {
        bytes memory nameBytes = bytes(name);
        bytes memory symbolBytes = new bytes(5);
        
        // Use the first 5 characters, or pad with 'X' if too short
        for (uint256 i = 0; i < 5; i++) {
            if (i < nameBytes.length) {
                // Convert to uppercase if it's a lowercase letter
                bytes1 char = nameBytes[i];
                if (char >= 0x61 && char <= 0x7A) { // a-z
                    char = bytes1(uint8(char) - 32); // convert to A-Z
                }
                symbolBytes[i] = char;
            } else {
                symbolBytes[i] = 0x58; // 'X'
            }
        }
        
        return string(symbolBytes);
    }
    
    /**
     * @dev Checks if a token exists for a given NFT ID
     * @param nftId The ID of the NFT
     * @return Whether a token exists
     */
    function tokenExists(uint256 nftId) external view returns (bool) {
        return tokensByNFTId[nftId] != address(0);
    }
    
    /**
     * @dev Gets the token address for a given NFT ID
     * @param nftId The ID of the NFT
     * @return The address of the token
     */
    function getTokenAddress(uint256 nftId) external view returns (address) {
        return tokensByNFTId[nftId];
    }
} 