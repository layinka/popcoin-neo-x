// // SPDX-License-Identifier: MIT

// pragma solidity ^0.8.17;

// contract BondingCurve {
//     uint256 public supply;
//     uint256 public basePrice;
//     uint256 public coefficient;
//     uint256 public priceFloor;
//     uint256 public priceCeiling;


//     mapping(address => uint256) public balances;

//     uint256 public targetMarketCap;
//     bool public salesUnlocked;

//     constructor() {
//         supply = 0;
//         basePrice = 1 ether; // adjustable base price
//         coefficient = 2; // adjustable coefficient
//         priceFloor = 0.5 ether; // adjustable price floor
//         priceCeiling = 5 ether; // adjustable price ceiling

//         targetMarketCap = 10000 ether; // set target market capitalization
//         salesUnlocked = false;
//     }

    

//     function getPrice() public view returns (uint256) {
//         uint256 price = basePrice * (supply ^ coefficient);
//         return min(max(price, priceFloor), priceCeiling);
//     }

//     function getMarketCap() public view returns (uint256) {
//         return supply * getPrice();
//     }


//     function buy(address user, uint256 amount) public {
//         // update user balance and total supply
//         balances[user] += amount;
//         supply += amount;
//         // update price and market capitalization
//         uint256 price = getPrice();
//         uint256 marketCap = getMarketCap();
//         // check if target market capitalization reached
//         if (marketCap >= targetMarketCap) {
//             salesUnlocked = true;
//         }
//     }

//     function sell(address user, uint256 amount) public {
//         // check if sales are unlocked
//         require(salesUnlocked, "Sales are locked");
//         // update user balance and total supply
//         balances[user] -= amount;
//         supply -= amount;
//     }

//     function mint(address to, uint256 amount) public {
//         // check if target market capitalization reached
//         require(!salesUnlocked, "Target market capitalization reached");
//         // mint new tokens
//         supply += amount;
//         balances[to] += amount;
//     }

//     function getHolders() public view returns (address[] memory) {
//         address[] memory holders = new address[](0);
//         for (uint i = 0; i< balances.length; i++) {
//             address user = balances[i];
//             if (balances[user] > 0) {
//                 holders.push(user);
//             }
//         }
//         return holders;
//     }

// }


// function min(uint256 a, uint256 b) internal pure returns (uint256) {
//     return a < b ? a : b;
// }

// function max(uint256 a, uint256 b) internal pure returns (uint256) {
//     return a > b ? a : b;
// }


