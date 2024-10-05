// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Test{

    using SafeERC20 for ERC20;

    uint public posCount;

   

    constructor(){
        
    }


    
    function t() public {
        posCount++;       

    }

    

   

    function  r() public view returns(uint) {
        return posCount;
    }

    

    function  testPay(address tokenAddress) public  {
        ERC20 token = ERC20(tokenAddress);
        token.safeTransferFrom(msg.sender, address(this),  (10**token.decimals()) / 10000000 );
    }

    


}