// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./FunToken.sol";

error NotEnoughFee(uint feeToPay);
error NotEnoughBalance(uint balance);
error UnsupportedRouter();

contract PopCoinFactory is Ownable {

    event TokenCreated(address creator, address tokenAddress);

    event TokenTraded(
        address indexed trader, 
        address indexed tokenAddress, 
        uint indexed tradeType,  //0 for Buy, 1 for Sell
        uint tokensTraded, 
        uint amountPaid
    );
    
    mapping(address => address[]) public ownerTokens;

    mapping(address => address) public tokenCreators; // token -> creator

    uint public tokenCount;

    address[] public tokens;

    address private adminPaymentAddress;

    uint public fee = 0.0005 ether;
    uint public targetMarketCap=30 ether;

    uint256 deployLiquidityFee=1.5 ether; 

    uint256 liquidityAmount=6 ether; 

    uint256 public transactionFeePercent=100; // Fee percentage for buy and sell - 1%
    

    mapping(address => bool) public routersSupported; 
    

    constructor(address[4] memory _dexRouterAddresses) Ownable(msg.sender) {
        adminPaymentAddress=msg.sender;
        // dexRouterAddress=_dexRouterAddress;

        for(uint i=0; i< _dexRouterAddresses.length; i++){
            if(_dexRouterAddresses[i]!= address(0)){
                routersSupported[_dexRouterAddresses[i]]= true;
            }
        }
    }

    function switchDexRouterSupport(address _dexRouterAddress, bool supported) public onlyOwner {
        if(_dexRouterAddress!= address(0)){
            routersSupported[_dexRouterAddress]= supported;
        }
    }


    // 
    function createToken(string memory name,string memory symbol,uint _initialBuyInEth, address dexRouterAddress) public payable {

        if(msg.value<fee+_initialBuyInEth) revert NotEnoughFee(fee);

        if(!routersSupported[dexRouterAddress]) revert UnsupportedRouter();
                
        FunToken token = new FunToken(name, symbol, targetMarketCap,transactionFeePercent, adminPaymentAddress,  20, dexRouterAddress, msg.sender,_initialBuyInEth, deployLiquidityFee, liquidityAmount );
        address tokenAddress = address(token);

        if(_initialBuyInEth>0){
            (bool success, ) = tokenAddress.call{value: _initialBuyInEth}("");
            require(success, "Transfer InitialEth failed");
        }
        
        ownerTokens[msg.sender].push(tokenAddress);
        tokenCreators[tokenAddress]=msg.sender;
        tokens.push(tokenAddress);


        
        emit TokenCreated(msg.sender, tokenAddress);
        tokenCount++;       

    }


    function  getTokens(uint skip, uint take) public view returns(address[] memory) {
        address[] memory list = new address[](take) ;
        for (uint256 i=skip; i < skip + take ; i++) {
            list[i-skip] = tokens[i]; 
        }
        return list;
    }

    

   
   function  getOwnerTokensCount(address owner) public view returns(uint) {
        
        return ownerTokens[owner].length;
    }

    function  getTokenCreator(address token) public view returns(address) {
        
        return tokenCreators[token];
    }

    function  getOwnerTokens(address owner,uint skip, uint take) public view returns(address[] memory) {
        address[] memory list = new address[](take) ;
        for (uint256 i=skip; i < skip + take ; i++) {
            list[i-skip] = ownerTokens[owner][i]; 
        }
        return list;
    }

    function  changeAdminPaymentAddress(address newAdminPaymentAddress) public onlyOwner  {
        
        adminPaymentAddress = newAdminPaymentAddress;
    }

    function  changeFee(uint newFee) public onlyOwner  {
        
        fee = newFee;
    }

    function  changeDeployLiquidityFee(uint newFee) public onlyOwner  {
        
        deployLiquidityFee = newFee;
    }

    function  changeLiquidityAmount(uint newAmount) public onlyOwner  {
        
        liquidityAmount = newAmount;
    }

    function  withdrawFrom(FunToken funToken, uint amount) public onlyOwner  {
        
        funToken.withdraw(payable(msg.sender), amount);
    }


    function  withdrawFee(address to, uint amount) public onlyOwner  {
        
        uint balance = address(this).balance;
        if(amount>=balance){
            if(to==address(0)){
                to=adminPaymentAddress;
            }

            payable(to).transfer(amount);
        }else {
            revert NotEnoughBalance(balance);
        }
    }

    
    function notifyTrade(address trader, address tokenAddress, uint tradeType, uint tokensTraded, uint amountPaid) public {
        if(tokenAddress!= msg.sender || tokenCreators[tokenAddress]==address(0)){// token is not issued by Factory
            revert('Token Not Issued by Factory');
        }

        emit TokenTraded(trader,tokenAddress,tradeType,tokensTraded,amountPaid);
    }
}