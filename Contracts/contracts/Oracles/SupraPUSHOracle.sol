// SPDX-License-Identifier: AGPL-1.0
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ISupraSValueFeed.sol";



contract SupraPUSHOracle is Ownable {
    error InvalidPair();
    

    ISupraSValueFeed private sValueFeed; // pointer to supra router
    


    address public supraValueFeedAddress ; // router address for  Supra


    //GAS_USDT
    mapping(uint => bool) isValidPair;
    

    event WhitelistPair(address indexed caller, uint[] ratePairs);
    event BlackListPair(address indexed caller, uint[] ratePairs);


    constructor(address _supraValueFeedAddress, uint[] memory ratePairIndexes) Ownable(msg.sender) {
        supraValueFeedAddress= _supraValueFeedAddress;
        whitelistSupraPair(ratePairIndexes);
        sValueFeed = ISupraSValueFeed(supraValueFeedAddress);
    }


    function whitelistSupraPair(uint[] memory pairs) public onlyOwner {
        uint256 len = pairs.length;
        for (uint256 i = 0; i < len; i++) {
            isValidPair[pairs[i]] = true;
        }
        emit WhitelistPair(msg.sender, pairs);
    }

    function blacklistSupraPair(uint[] memory pairs) public onlyOwner {
        uint256 len = pairs.length;
        for (uint256 i = 0; i < len; i++) {
            isValidPair[pairs[i]] = false;
        }
        emit BlackListPair(msg.sender, pairs);
    }


    
    function getPrice(uint256 _priceIndex)
        public
        view
        returns (ISupraSValueFeed.priceFeed memory)
    {
        require(isValidPair[_priceIndex], InvalidPair());
        return sValueFeed.getSvalue(_priceIndex);
    }

    function getPrices(uint256[] memory _priceIndexes)
        public
        view
        returns (ISupraSValueFeed.priceFeed[] memory)
    {
        for (uint i = 0; i < _priceIndexes.length; i++) {
            require(isValidPair[_priceIndexes[i]], InvalidPair());
        }
        
        return sValueFeed.getSvalues(_priceIndexes);
    }

    function updateSupraSvalueFeed(ISupraSValueFeed _newSValueFeed) external onlyOwner {
        sValueFeed = _newSValueFeed;
    }

}