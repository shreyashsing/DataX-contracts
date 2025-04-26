// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./DataNFT.sol";

contract Marketplace is ReentrancyGuard {
    IERC20 public oceanToken;
    IDataNFT public dataNFT;

    struct Dataset {
        uint256 id;
        address owner;
        uint256 price;
        bool isForSale;
    }

    // Custom errors
    error NotOwner();
    error NoDataTokenLinked();
    error NoCIDSet();
    error NotApproved();
    error NotForSale();
    error PaymentFailed();
    error TransferFailed();
    error InvalidDatasetCID();

    mapping(uint256 => Dataset) public datasets;

    event DatasetListed(uint256 indexed id, uint256 price, string datasetCID);
    event DatasetSold(uint256 indexed id, address buyer, uint256 price, string datasetCID, bytes32 decryptionKey);
    event MarketplaceFeeCollected(uint256 indexed id, uint256 fee);

    constructor(address _oceanToken, address _dataNFT) {
        oceanToken = IERC20(_oceanToken);
        dataNFT = IDataNFT(_dataNFT);
    }

    // List a dataset for sale
    function listDataset(uint256 _id, uint256 _price) public {
        if (dataNFT.ownerOf(_id) != msg.sender) revert NotOwner();
        if (dataNFT.getDatatoken(_id) == address(0)) revert NoDataTokenLinked();
        
        string memory datasetCID = dataNFT.datasetCIDs(_id);
        if (bytes(datasetCID).length == 0) revert NoCIDSet();

        // Ensure Marketplace is approved to transfer the NFT
        if (!dataNFT.isApprovedForAll(msg.sender, address(this)) && 
            dataNFT.getApproved(_id) != address(this)) {
            revert NotApproved();
        }

        datasets[_id] = Dataset(_id, msg.sender, _price, true);
        emit DatasetListed(_id, _price, datasetCID);
    }

    // Buy a dataset NFT
    function buyDataset(uint256 _id) public nonReentrant returns (string memory, bytes32) {
        Dataset memory dataset = datasets[_id];
        if (!dataset.isForSale) revert NotForSale();
        
        // Save the owner before we update the listing
        address seller = dataset.owner;
        uint256 price = dataset.price;
        
        // Update listing state first to prevent reentrancy
        datasets[_id].isForSale = false;
        datasets[_id].owner = msg.sender;

        // Try to execute the payment
        bool paymentSuccess = oceanToken.transferFrom(msg.sender, seller, price);
        if (!paymentSuccess) revert PaymentFailed();

        // Transfer NFT after successful payment
        try dataNFT.transferFrom(seller, msg.sender, _id) {
            // Success path
        } catch {
            revert TransferFailed();
        }

        // Retrieve dataset CID and decryption key
        string memory datasetCID;
        bytes32 decryptionKey;
        
        try dataNFT.accessData(_id, 0) returns (string memory cid, bytes32 key) {
            datasetCID = cid;
            decryptionKey = key;
        } catch {
            // If accessData fails, try to get the CID directly
            datasetCID = dataNFT.datasetCIDs(_id);
            decryptionKey = 0;
        }
        
        if (bytes(datasetCID).length == 0) revert InvalidDatasetCID();

        emit DatasetSold(_id, msg.sender, price, datasetCID, decryptionKey);
        return (datasetCID, decryptionKey);
    }

    // Get dataset info
    function getDataset(uint256 _id) public view returns (Dataset memory, string memory) {
        Dataset memory dataset = datasets[_id];
        string memory datasetCID = dataNFT.datasetCIDs(_id);
        return (dataset, datasetCID);
    }

    // Check if user has appropriate approvals
    function checkApprovals(uint256 _id, address user) public view returns (bool) {
        return dataNFT.isApprovedForAll(user, address(this)) || 
               dataNFT.getApproved(_id) == address(this);
    }
}
