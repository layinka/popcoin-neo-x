// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../IDexRouter.sol";

import "hardhat/console.sol";

import { FixedPointMathLib } from "solmate/src/utils/FixedPointMathLib.sol";
import { SafeTransferLib } from "solmate/src/utils/SafeTransferLib.sol";
import { ERC20 as SolmateERC20 } from "solmate/src/tokens/ERC20.sol";
import {FunTokenV2} from "./FunToken.sol";

error NotPermitted();
error Paused();
error InsufficientPayment();
error InvalidAmountIn();
error InsufficientOutput();
error DeadlineExceeded();
error InvalidToken();
error FeeTooHigh();
error NotEnoughBalanceForFees();
error NotEnoughFee(uint feeToPay);
error NotEnoughBalance();
error TokenApprovalRequired();
error UnsupportedRouter();
error ExceededMaxGasPrice(uint maxGasPrice);

struct TokenCreateInfo {
    string name;
    string symbol;
    string description;
    string logo;
    string banner;
    string twitter;
    string telegram;
    string website;
    address routerAddress;
    uint initialCreatorBuy;
}
struct Pool {
    FunTokenV2 token;
    uint256 tokenReserve;
    uint256 virtualTokenReserve;
    uint256 ethReserve;
    uint256 virtualEthReserve;
    uint256 lastPrice;
    uint256 lastMcapInEth;
    uint256 lastTimestamp;
    uint256 lastBlock;
    address creator;
    address routerAddress;
    bool migrated;
}

contract PopCoinFactoryV2 is ReentrancyGuard, Ownable {
    using FixedPointMathLib for uint256;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    uint256 public constant FEE_DENOMINATOR = 100_00;
    
    uint256 public constant INIT_VIRTUAL_TOKEN_RESERVE = 1073000000 ether;
    uint256 public constant INIT_REAL_TOKEN_RESERVE = 793100000 ether;
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether;

    uint256 public initVirtualEthReserve;
    uint256 public migrationThreshold;
    uint256 public CURVE_CONSTANT;
    uint256 public deployLiquidityFee=1.5 ether;
    uint256 public tokenCreateFee=0.0005 ether;
    uint256 public transactionFeePercent=100;
    
    
    address payable public adminPaymentAddress;

    mapping(address => bool) public routersSupported; 

    bool public paused;
    mapping(address => Pool) public tokenPool;

     mapping(address => address[]) public ownerTokens;

    mapping(address => address) public tokenCreators; // token -> creator

    event TokenCreated(
        address indexed creator,
        address indexed tokenAddress,
        string name,
        string symbol,
        string description,
        string logo,
        string banner,
        string twitter,
        string telegram,
        string website,
        address routerAddress,
        uint256 timestamp
    );
    event PriceUpdated(
        address indexed token,
        address indexed trader,
        uint256 price,
        uint256 mcapEth,
        uint256 timestamp
    );
    event TokenTraded(
        address indexed trader,
        address indexed tokenAddress,
        uint256 tokensTraded,
        uint256 amountPaid,
        uint256 fee,
        uint256 timestamp,
        bool isBuy
    );
    event LiquidityMigrated(
        address indexed tokenAddress,
        address indexed pair, 
        uint256 ethAmount, 
        uint256 tokenAmount, 
        uint256 fee, 
        uint256 timestamp
    );


    uint256 public maxGasPrice = 1 * 10**18; // Adjustable value
    

    modifier onlyValidGasPrice() {    
        require(tx.gasprice <= maxGasPrice, ExceededMaxGasPrice(maxGasPrice));    
        _;  
    }

    modifier onlyUnPaused() {
        if (paused) revert Paused();
        _;
    }
    modifier checkDeadline(uint256 deadline) {
        if (block.timestamp > deadline) revert DeadlineExceeded();
        _;
    }


    constructor(  
        uint256 _initVirtualEthReserve,
        uint256 _tokenCreateFee,
        uint256 _deployLiquidityFee,        
        uint _transactionFeePercent,
        address[4] memory _dexRouterAddresses,
        uint256 _maxGasPrice
    ) Ownable(msg.sender) {
        adminPaymentAddress = payable(msg.sender);
        deployLiquidityFee=_deployLiquidityFee;
        tokenCreateFee=_tokenCreateFee;
        transactionFeePercent=_transactionFeePercent;
        paused = false;
        maxGasPrice=_maxGasPrice;

        initVirtualEthReserve = _initVirtualEthReserve;
        CURVE_CONSTANT = initVirtualEthReserve * INIT_VIRTUAL_TOKEN_RESERVE;
        migrationThreshold = CURVE_CONSTANT / (INIT_VIRTUAL_TOKEN_RESERVE - INIT_REAL_TOKEN_RESERVE) - initVirtualEthReserve;

        for(uint i=0; i< _dexRouterAddresses.length; i++){
            if(_dexRouterAddresses[i]!= address(0)){
                routersSupported[_dexRouterAddresses[i]]= true;
            }
        }
    }

    function setMaxGasPrice(uint256 _maxGasPrice) public onlyOwner {    
        maxGasPrice=_maxGasPrice; 
        
    }


    function createToken(TokenCreateInfo memory tokenInfo) public payable onlyUnPaused returns (address) {
        
        if (msg.value < tokenCreateFee + tokenInfo.initialCreatorBuy) revert InsufficientPayment();
        if (tokenCreateFee > 0) SafeTransferLib.safeTransferETH(adminPaymentAddress, tokenCreateFee);
        FunTokenV2 token = new FunTokenV2(tokenInfo.name, tokenInfo.symbol, address(this), msg.sender, TOTAL_SUPPLY, tokenInfo.routerAddress);
        Pool storage pool = tokenPool[address(token)];
        pool.token = token;
        pool.tokenReserve = INIT_REAL_TOKEN_RESERVE;
        pool.virtualTokenReserve = INIT_VIRTUAL_TOKEN_RESERVE;
        pool.ethReserve = 0;
        pool.virtualEthReserve = initVirtualEthReserve;
        pool.lastPrice = initVirtualEthReserve.divWadDown(INIT_VIRTUAL_TOKEN_RESERVE);
        pool.lastMcapInEth = TOTAL_SUPPLY.mulWadUp(pool.lastPrice);
        pool.lastTimestamp = block.timestamp;
        pool.lastBlock = block.number;
        pool.creator = msg.sender;
        pool.routerAddress=tokenInfo.routerAddress;
        pool.migrated = false;

        ownerTokens[msg.sender].push(address(token));
        tokenCreators[address(token)]=msg.sender; 

        emit TokenCreated(
            msg.sender,
            address(token),
            tokenInfo.name,
            tokenInfo.symbol,
            tokenInfo.description,
            tokenInfo.logo,
            tokenInfo.banner,
            tokenInfo.twitter,
            tokenInfo.telegram,
            tokenInfo.website,
            tokenInfo.routerAddress,
            block.timestamp
        );
        emit PriceUpdated(
            address(token), 
            msg.sender, 
            pool.lastPrice, 
            pool.lastMcapInEth, 
            block.timestamp
        );

        if(tokenInfo.initialCreatorBuy>0){
            
            _swapEthForTokens(address(token),tokenInfo.initialCreatorBuy, 0, block.timestamp+1000, true);
        }
        return address(token);
    }

    function _swapEthForTokens(address token, uint256 amountIn, uint256 amountOutMin, uint256 deadline, bool suspendFee) 
        private 
        onlyUnPaused 
        checkDeadline(deadline) 
        returns (uint256 amountOut) 
    {
        
        if (amountIn == 0) revert InvalidAmountIn();
        uint256 fee = 0;
        
        if (tokenPool[token].migrated) {
            
            ( amountOut, fee ) = _swapETHForTokenOnRouter(token, amountIn, amountOutMin, msg.sender);
        } else {
            
            if(!suspendFee){
                fee = amountIn * transactionFeePercent / FEE_DENOMINATOR;
                amountIn -= fee;
                SafeTransferLib.safeTransferETH(adminPaymentAddress, fee);
            }
            
            
            if (tokenPool[token].creator == address(0)) revert InvalidToken();
            
            // Add Fee to calcAmountOut Check, since it alway uses fee in calculation
            (uint newVirtualEthReserve,uint newVirtualTokenReserve,uint amountOut1) = _calcAmountOutFromEth(token, amountIn+fee);
            
            amountOut=amountOut1;
            if (amountOut < amountOutMin) revert InsufficientOutput();

            tokenPool[token].virtualEthReserve = newVirtualEthReserve;
            tokenPool[token].virtualTokenReserve = newVirtualTokenReserve;
            tokenPool[token].lastPrice = newVirtualEthReserve.divWadDown(newVirtualTokenReserve);
            tokenPool[token].lastMcapInEth = TOTAL_SUPPLY.mulWadUp(tokenPool[token].lastPrice);
            tokenPool[token].lastTimestamp = block.timestamp;
            tokenPool[token].lastBlock = block.number;
            tokenPool[token].ethReserve += amountIn;            
            tokenPool[token].tokenReserve -= amountOut;
            
            SafeTransferLib.safeTransfer(SolmateERC20(token), msg.sender, amountOut);
            emit PriceUpdated(token, msg.sender, tokenPool[token].lastPrice, tokenPool[token].lastMcapInEth, block.timestamp);

            if (tokenPool[token].ethReserve >= migrationThreshold) {
                _migrateLiquidity(token);
            }
        }
        emit TokenTraded(msg.sender, token, amountOut,amountIn, fee, block.timestamp, true);
    }

    function swapEthForTokens(address token, uint256 amountIn, uint256 amountOutMin, uint256 deadline) 
        public 
        payable 
        onlyValidGasPrice
        nonReentrant 
        onlyUnPaused 
        checkDeadline(deadline) 
        
        returns (uint256 amountOut) 
    {
        
        if (msg.value < amountIn) revert InsufficientPayment();
        if (amountIn == 0) revert InvalidAmountIn();
        return _swapEthForTokens(token, amountIn, amountOutMin, deadline, false);
        
        
    }

    function swapTokensForEth(address token, uint256 tokensIn, uint256 amountOutMin, uint256 deadline)
        public
        onlyValidGasPrice
        nonReentrant
        onlyUnPaused
        checkDeadline(deadline)

        returns (uint256 amountOut)
    {
        uint256 fee = 0;
        if (tokensIn == 0) revert InvalidAmountIn();        
        SafeTransferLib.safeTransferFrom(SolmateERC20(token), msg.sender, address(this), tokensIn);
        if (tokenPool[token].migrated) {
            ( amountOut, fee ) = _swapTokenForETHOnRouter(token, tokensIn, amountOutMin, msg.sender);
        } else {
            if (tokenPool[token].creator == address(0)) revert InvalidToken();

            (uint newVirtualEthReserve,uint newVirtualTokenReserve,uint amountOut1)= _calcAmountOutFromToken(token, tokensIn );
            amountOut=amountOut1;
            tokenPool[token].virtualTokenReserve = newVirtualTokenReserve;
            tokenPool[token].virtualEthReserve = newVirtualEthReserve;
            tokenPool[token].lastPrice = newVirtualEthReserve.divWadDown(newVirtualTokenReserve);
            tokenPool[token].lastMcapInEth = TOTAL_SUPPLY.mulWadUp(tokenPool[token].lastPrice);
            tokenPool[token].lastTimestamp = block.timestamp;
            tokenPool[token].lastBlock = block.number;
            tokenPool[token].tokenReserve += tokensIn;
            tokenPool[token].ethReserve -= amountOut;

            fee = amountOut * transactionFeePercent / FEE_DENOMINATOR;
            amountOut -= fee;
            if (amountOut < amountOutMin-fee) revert InsufficientOutput();
            SafeTransferLib.safeTransferETH(adminPaymentAddress, fee);
            SafeTransferLib.safeTransferETH(msg.sender, amountOut);

            emit PriceUpdated(token, msg.sender, tokenPool[token].lastPrice, tokenPool[token].lastMcapInEth, block.timestamp);
        }
        emit TokenTraded(msg.sender, token, tokensIn, amountOut, fee, block.timestamp, false);
    }

    function _migrateLiquidity(address tokenAddress) private {
        if (tokenPool[tokenAddress].creator == address(0)) revert InvalidToken();
        Pool storage poolToken = tokenPool[tokenAddress];
        poolToken.lastTimestamp = block.timestamp;
        poolToken.lastBlock = block.number;

        uint256 fee = deployLiquidityFee;        
        if(poolToken.ethReserve < fee) revert NotEnoughBalanceForFees();
        SafeTransferLib.safeTransferETH(adminPaymentAddress, fee);
        
        uint256 ethAmount = poolToken.ethReserve - fee;
        if(address(this).balance < ethAmount) revert NotEnoughBalance();

        uint256 tokenAmount = TOTAL_SUPPLY - INIT_REAL_TOKEN_RESERVE;        

        FunTokenV2(tokenAddress).setIsApprovable(true);
        bool success = FunTokenV2(tokenAddress).approve(poolToken.routerAddress, tokenAmount);        
        if(!success){
            revert TokenApprovalRequired();
        }
        
        IDexRouter router = IDexRouter(poolToken.routerAddress) ;
        IDexFactory factory = IDexFactory(router.factory());
        address lpTokenPairAddress = factory.getPair(tokenAddress, router.WETH());
        
        if (lpTokenPairAddress == address(0)) {
            lpTokenPairAddress = factory.createPair(tokenAddress, router.WETH());
        }

        router.addLiquidityETH{ value: ethAmount }(
            tokenAddress,
            tokenAmount,
            tokenAmount,
            ethAmount,
            BURN_ADDRESS, // permanently lock the liquidity
            block.timestamp + 3 minutes
        );
        
        poolToken.migrated = true;
        poolToken.virtualEthReserve = 0;
        poolToken.virtualTokenReserve = 0;
        poolToken.ethReserve = 0;
        poolToken.tokenReserve = 0;
        emit LiquidityMigrated(tokenAddress, lpTokenPairAddress, ethAmount, tokenAmount, fee, block.timestamp);
    }

    function _calcAmountOutFromToken(address token, uint256 amountIn) private view returns (uint256 newVirtualEthReserve, uint256 newVirtualTokenReserve,uint256 amountOut) {
        if (amountIn == 0) revert InvalidAmountIn();

        newVirtualTokenReserve = tokenPool[token].virtualTokenReserve + amountIn;
        newVirtualEthReserve = CURVE_CONSTANT / newVirtualTokenReserve;
        amountOut = tokenPool[token].virtualEthReserve - newVirtualEthReserve;

        uint256 fee = amountOut * transactionFeePercent / FEE_DENOMINATOR;
        amountOut -= fee;
    }

    function calcAmountOutFromToken(address token, uint256 amountIn) public view returns (uint256 ) {
        (,,uint amountOut) = _calcAmountOutFromToken(token, amountIn);
        return amountOut;
    }

    function _calcAmountOutFromEth(address token, uint256 amountIn) private view returns (uint256 newVirtualEthReserve, uint256 newVirtualTokenReserve,uint256 amountOut) {
        if (amountIn == 0) revert InvalidAmountIn();
        
        uint256 fee = amountIn * transactionFeePercent / FEE_DENOMINATOR;
        
        amountIn -= fee;

        newVirtualEthReserve = tokenPool[token].virtualEthReserve + amountIn;
        newVirtualTokenReserve = CURVE_CONSTANT / newVirtualEthReserve;
        amountOut = tokenPool[token].virtualTokenReserve - newVirtualTokenReserve;

        
        if (amountOut > tokenPool[token].tokenReserve) {
            amountOut = tokenPool[token].tokenReserve;
        }
    }

    function calcAmountOutFromEth(address token, uint256 amountIn) public view returns (uint256 ) {
        (,,uint amountOut) = _calcAmountOutFromEth(token, amountIn);
        return amountOut;
    }

    function _swapETHForTokenOnRouter(address tokenAddress, uint256 amountIn, uint256 amountOutMin, address to) private returns (uint256, uint256) {
        
        if (msg.value < amountIn) revert InsufficientPayment();
        uint256 fee = (amountIn * transactionFeePercent) / FEE_DENOMINATOR;
        address[] memory path = new address[](2);
        IDexRouter router = IDexRouter(tokenPool[tokenAddress].routerAddress) ;
        path[0] = router.WETH();
        path[1] = tokenAddress;
        uint[] memory amounts = router.swapExactETHForTokens{value: amountIn - fee}(
            amountOutMin,
            path,
            to,
            block.timestamp + 1 minutes
        );
        uint amountOut = amounts[amounts.length - 1];
        SafeTransferLib.safeTransferETH(adminPaymentAddress, fee);
        return (amountOut, fee);
    }

    function _swapTokenForETHOnRouter(address tokenAddress, uint256 amountIn, uint256 amountOutMin, address to) private returns (uint256, uint256) {
        address[] memory path = new address[](2);
        path[0] = tokenAddress;

        IDexRouter router = IDexRouter(tokenPool[tokenAddress].routerAddress) ;
        path[1] = router.WETH();
        FunTokenV2(tokenAddress).approve(address(router), amountIn);
        uint[] memory amounts = router.swapExactTokensForETH(
            amountIn, 
            amountOutMin, 
            path,
            address(this), 
            block.timestamp + 1 minutes
        );
        uint amountOut = amounts[amounts.length - 1];
        uint256 fee = (amountOut * transactionFeePercent) / FEE_DENOMINATOR;
        SafeTransferLib.safeTransferETH(adminPaymentAddress, fee);
        SafeTransferLib.safeTransferETH(to, amountOut - fee);
        return (amountOut - fee, fee);
    }

    function changeInitVirtualEthReserve(uint256 value) external onlyOwner {
        initVirtualEthReserve = value;
        CURVE_CONSTANT = initVirtualEthReserve * INIT_VIRTUAL_TOKEN_RESERVE;
        migrationThreshold = CURVE_CONSTANT / (INIT_VIRTUAL_TOKEN_RESERVE - INIT_REAL_TOKEN_RESERVE) - initVirtualEthReserve;
    }

    
    function  changeAdminPaymentAddress(address newAdminPaymentAddress) public onlyOwner  {
        
        adminPaymentAddress = payable( newAdminPaymentAddress);
    }

    function changeCreationFee(uint256 value) external onlyOwner {
        tokenCreateFee = value;
    }
    
    function changeDeployLiquidityFee(uint256 value) public onlyOwner {
        deployLiquidityFee = value;
    }

    function changeTransactionFeePercent(uint256 value) external onlyOwner {
        transactionFeePercent = value;
    }

    

    function setPaused(bool _val) external onlyOwner {
        paused = _val;
    }

    function switchDexRouterSupport(address _dexRouterAddress, bool supported) public onlyOwner {
        if(_dexRouterAddress!= address(0) && routersSupported[_dexRouterAddress] != supported){
            routersSupported[_dexRouterAddress]= supported;
        }
    }

    // function  getTokens(uint skip, uint take) public view returns(address[] memory) {
    //     address[] memory list = new address[](take) ;
    //     for (uint256 i=skip; i < skip + take ; i++) {
    //         list[i-skip] = tokens[i]; 
    //     }
    //     return list;
    // }
   
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

    

    function  withdrawFee(address to, uint amount) public onlyOwner  {
        
        uint balance = address(this).balance;
        if(amount>=balance){
            if(to==address(0)){
                to=adminPaymentAddress;
            }

            payable(to).transfer(amount);
        }else {
            revert NotEnoughBalance();
        }
    }

    
    // function notifyTrade(address trader, address tokenAddress, uint tradeType, uint tokensTraded, uint amountPaid) public {
    //     if(tokenAddress!= msg.sender || tokenCreators[tokenAddress]==address(0)){// token is not issued by Factory
    //         revert('Token Not Issued by Factory');
    //     }

    //     emit TokenTraded(trader,tokenAddress,tradeType,tokensTraded,amountPaid);
    // }


    receive() external payable {}
}
