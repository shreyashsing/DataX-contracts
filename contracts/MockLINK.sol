// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockLINK
 * @dev A simple ERC20 token to simulate LINK tokens on local development chains
 */
contract MockLINK is ERC20 {
    address private _owner;
    
    constructor() ERC20("Mock Chainlink Token", "LINK") {
        _owner = msg.sender;
        // Mint initial supply to deployer
        _mint(msg.sender, 1000000 * 10**18); // 1,000,000 LINK
    }
    
    modifier onlyOwner() {
        require(msg.sender == _owner, "Not owner");
        _;
    }

    /**
     * @dev Mint new tokens
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
} 