// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./DataNFT.sol";

contract Marketplace {
    IERC20 public oceanToken;
    DataNFT public dataNFT;

    struct Dataset {
        uint256 id;
        address owner;
        uint256 price;
        bool isForSale;
    }

    mapping(uint256 => Dataset) public datasets;

    constructor(address _oceanToken, address _dataNFT) {
        oceanToken = IERC20(_oceanToken);
        dataNFT = DataNFT(_dataNFT);
    }

    function listDataset(uint256 _id, uint256 _price) public {
        require(dataNFT.ownerOf(_id) == msg.sender, "Not the owner");
        datasets[_id] = Dataset(_id, msg.sender, _price, true);
    }

    function buyDataset(uint256 _id) public {
        Dataset memory dataset = datasets[_id];
        require(dataset.isForSale, "Not for sale");

        oceanToken.transferFrom(msg.sender, dataset.owner, dataset.price);
        dataNFT.transferFrom(dataset.owner, msg.sender, _id);
        datasets[_id].isForSale = false;
    }
}
