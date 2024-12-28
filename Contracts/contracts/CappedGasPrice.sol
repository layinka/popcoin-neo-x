// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;



error ExceededMaxGasPrice(uint maxGasPrice);

contract CappedGasPrice  {  
    uint256 public maxGasPrice = 1 * 10**18; // Adjustable value
    address owner;

    modifier validGasPrice() {    
        require(tx.gasprice <= maxGasPrice, ExceededMaxGasPrice(maxGasPrice));    
        _;  
    }

    modifier onlyOwner() {    
        require(msg.sender==owner, ExceededMaxGasPrice(maxGasPrice));    
        _;  
    }

    constructor(uint256 _maxGasPrice, address _owner)  {
        maxGasPrice=_maxGasPrice;
        owner=_owner;
    }
    

    function setMaxGasPrice(uint256 _maxGasPrice) public onlyOwner {    
        maxGasPrice=_maxGasPrice; 
        
    }

    function changeOwner(address _owner) public onlyOwner {    
        owner=_owner;
        
    }
        
}