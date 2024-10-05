// SPDX-License-Identifier: AGPL-1.0
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./IDexRouter.sol";
import "hardhat/console.sol";

interface IPopCoinFactory {
    function notifyTrade(address trader, address tokenAddress, uint tradeType, uint tradePrice, uint tradeAmount) external;
}


 // Custom errors
error InsufficientETH(uint256 sent, uint256 required);
error InsufficientTokens(uint256 available, uint256 required);
error InsufficientContractETH(uint256 available, uint256 required);
error TransferFailed();
error BalanceExceeded(uint256 available, uint256 required);
error ExceededMaxBuy(uint maxBuy);
error LiquidityAlreadySent();
error SlippageExceeded(uint256 current, uint256 max);
error ExceedsMarketCap();

contract FunToken is ERC20, ReentrancyGuard, Ownable {
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

	IDexRouter public immutable v2Router;
	uint8 decimalPlaces=18;
    uint256 public targetMarketCap;                // Target market cap in wei
    uint256 public transactionFeePercent;                     // Fee percentage for transactions (in basis points)
    address public feeAddress;                     // Address to receive transaction fees
    uint256 public liquidityDeploymentPercent;     // Percentage of liquidity to deploy to DEX
    address public routerAddress;                     // Address of the DEX to deploy liquidity to
    uint256 public immutable fixedSupply=1_000_000_000 ether;          // Fixed supply of the token
    uint256 public immutable initialFixedSupply=800_000_000 ether;          // Fixed supply of the token

    uint256 public netBoughtTokens;                // Tracks the net amount of tokens bought
    uint256 public ethPaid; 
	uint256 public maxBuy = 5 ether;
    uint256 deployLiquidityFee=5 ether; 

    // address popCoinFactory;
    IPopCoinFactory popCoinFactory;

    bool public liquiditySent = false;

    uint256 constant private MAX_INT = 2**256 - 1;

     // Constants derived from the fitting y=f- t/(k+x) where x=supply in Sale Coin
    uint256 private constant F = 1071000120;
    uint256 private constant T = 11229068400;
    uint256 private constant K = 10.48465702 ether;  // 10.48465702

    // event BoughtToken(address indexed buyer, uint amountPaid);
    // event SoldToken(address indexed buyer, uint amountPaid);
    event LiquidityDeployed();

    
    uint256 private constant PRECISION = 10**18; // To maintain precision for Ether and token calculations

    uint256 public liquidityAmount;
    //todo
    //resrtrict owner withdrawal until coins have been moved to DEX

    constructor(
        string memory name,
        string memory symbol,        
        uint256 _targetMarketCap,
        uint256 _transactionFeePercent,
        address _feeAddress,
        uint256 _liquidityDeploymentPercent,
        address _routerAddress,
		address _creator,
		uint _initialBuyInEth,
        uint256 _deployLiquidityFee,
        uint256 _liquidityAmount
    ) ERC20(name, symbol) Ownable(_creator) {
        popCoinFactory=IPopCoinFactory( msg.sender);
        targetMarketCap = _targetMarketCap;
        transactionFeePercent = _transactionFeePercent;
        feeAddress = _feeAddress;
        liquidityDeploymentPercent = _liquidityDeploymentPercent;
        routerAddress = _routerAddress;
		v2Router = IDexRouter(_routerAddress);
        deployLiquidityFee=_deployLiquidityFee;
        liquidityAmount=_liquidityAmount;
        // console.log("INITIAL ethPaid %d ",ethPaid);
        // Initially mint the initial fixed supply to the contract itself
		uint initialTokensForCreator = calculateNumberOfTokensToBuy(_initialBuyInEth);
        _mint(address(this), initialFixedSupply - initialTokensForCreator);
		_mint(_creator, initialTokensForCreator);
        ethPaid+=_initialBuyInEth;
        netBoughtTokens+=initialTokensForCreator;
        // console.log("INITIAL2 ethPaid %d ",ethPaid);

        // console.log("creator %s , _initialBuyInEth %d, initialTokensForCreator %d ",_creator, _initialBuyInEth, initialTokensForCreator);
    }

	function decimals() public view virtual override returns (uint8) {
		return decimalPlaces;
	}

    // returns actual no  not scaled t 18 decimals
    function tokensIssued(uint supplyInEth) public pure returns (uint) {
        
        // Scale up supplyInEth by the precision factor to maintain accuracy during division
        uint256 scaledSupply = (supplyInEth * PRECISION) / 10**18; // Now, scaledSupply has the same precision as 1 ETH

        // Perform the calculation with scaledSupply
        // Here, we add the precision factor to 30 to keep the units consistent during the calculation
        uint256 result = F - T * PRECISION / (K  + scaledSupply);
        // console.log("tokensIssued::  supplyInEth %d, tokens %d ",supplyInEth, result);
        return result;
    }


    function price(uint supplyInEth) public pure returns (uint) {
        uint tokensIssued = tokensIssued(supplyInEth);

        return supplyInEth/tokensIssued;
    }

    // Function to calculate the amount of tokens T for given Ether (ETH) paid
    function calculateNumberOfTokensToBuy( uint256 amount) public view returns (uint256) {
        return calculateNumberOfTokensToBuy(ethPaid,amount);
    }
    // Function to calculate the amount of tokens T for given Ether (ETH) paid
    function calculateNumberOfTokensToBuy(uint256 totalEthInContract, uint256 amount) public view returns (uint256) {
        uint256 initialTokens = tokensIssued(totalEthInContract);
        uint256 newEthTotal = totalEthInContract + amount;
        uint256 finalTokens = tokensIssued(newEthTotal);

        uint256 tokensToIssue = finalTokens - initialTokens;
        // console.log('newEthTotal %d ',newEthTotal);
        // console.log('totalEthInContract %d , initialTokens %d , finalTokens %d ',totalEthInContract, initialTokens, finalTokens);

        return tokensToIssue * PRECISION;
    }

    // Function to calculate the amount of Ether (ETH) needed to buy a specific number of tokens (T)
    function calculateNumberOfTokensToBuyWithTokens( uint256 amount) public view returns (uint256) {
        return calculateNumberOfTokensToBuyWithTokens(ethPaid,amount);
    }

    // Function to calculate the amount of Ether (ETH) needed to buy a specific number of tokens (T)
    function calculateNumberOfTokensToBuyWithTokens(uint256 totalEthInContract,  uint256 tokensToBuy) public view returns (uint256) {
        
        uint256 initialTokens = tokensIssued(totalEthInContract);
        // console.log(" initialTokens %d, tokensToBuy %d", initialTokens, tokensToBuy);
        uint256 targetTokens = (initialTokens*PRECISION + tokensToBuy)/PRECISION;
        
        // Invert the formula to solve for x (Ether) when we know y (tokens)
        uint256 targetEth = T * PRECISION / (F - targetTokens) - K;
        // console.log("targetTokens %d, targetEth %d, tokensToBuy %d",targetTokens, targetEth, tokensToBuy);

        uint256 ethNeeded = targetEth  - totalEthInContract;
        // console.log("totalEthInContract %d, realBalance %d, ethNeeded %d",totalEthInContract, address(this).balance, ethNeeded);
        return ethNeeded;
    }

    


    // Function to calculate the amount of Ether (ETH) returned for selling a certain amount of tokens (T)
    function calculateNumberOfETHSoldForToken( uint256 tokensToSell) public view returns (uint256) {
        // console.log(" ethPaid %d, tokensToSell %d",ethPaid, tokensToSell);
        return calculateNumberOfETHSoldForToken(ethPaid,tokensToSell);
    }

    function calculateNumberOfETHSoldForToken(uint256 totalEthInContract,  uint256 tokensToSell) public view returns (uint256) {
        // console.log("SELLING:: tokensToSell %d ", tokensToSell );
        uint256 initialTokens = tokensIssued(totalEthInContract);
        // console.log("SELLING:: initialTokens %d , totalEthInContract %d ", initialTokens, totalEthInContract );
        uint256 targetTokens = initialTokens - tokensToSell/PRECISION;

        console.log("SELLING:: initialTokens %d, tokensToSell %d , targetTokens %d ", initialTokens,tokensToSell, targetTokens );

        // // Invert the formula to solve for x (Ether) when we know y (tokens)
        // // y = F - T / (K + x)
        // // => T / (K + x) = F - y
        // // => x = T / (F - y) - K
        // // console.log("SELLING:: T  %d ", (T ) );
        console.log("SELLING:: K  %d, K/PRECISION %d ", K, (K/PRECISION ) );
        console.log("SELLING:: (F - targetTokens) %d ", (F - targetTokens) );
        console.log("SELLING:: (T * PRECISION  / (F - targetTokens)) %d ", (T * PRECISION  / (F - targetTokens)) );
        uint256 targetEth = (T * PRECISION  / (F - targetTokens)) - (K);
        console.log("SELLING:: totalEthInContract %d, targetEth %d ",totalEthInContract,  targetEth );
        uint256 ethToReturn = totalEthInContract - targetEth ;
        console.log("SELLING:: ethToReturn %d ", ethToReturn );

        return ethToReturn;
    }

    // function calculateNumberOfETHSoldForTokenOld(uint256 totalEthInContract,  uint256 tokensToSell) public view returns (uint256) {
    //     // console.log("SELLING:: tokensToSell %d ", tokensToSell );
    //     uint256 initialTokens = tokensIssued(totalEthInContract);
    //     // console.log("SELLING:: initialTokens %d , totalEthInContract %d ", initialTokens, totalEthInContract );
    //     uint256 targetTokens = initialTokens - tokensToSell/PRECISION;

    //     // console.log("SELLING:: initialTokens %d, tokensToSell %d , targetTokens %d ", initialTokens,tokensToSell, targetTokens );

    //     // Invert the formula to solve for x (Ether) when we know y (tokens)
    //     // y = F - T / (K + x)
    //     // => T / (K + x) = F - y
    //     // => x = T / (F - y) - K
    //     // console.log("SELLING:: (T * PRECISION) %d ", (T * PRECISION) );
    //     // console.log("SELLING:: (F - targetTokens) %d ", (F - targetTokens) );
    //     uint256 targetEth = (T * PRECISION / (F - targetTokens)) - (K);
    //     console.log("SELLING:: targetEth %d ", targetEth );
    //     uint256 ethToReturn = totalEthInContract - targetEth / PRECISION;
    //     console.log("SELLING:: ethToReturn %d ", ethToReturn );

    //     return ethToReturn;
    // }

    




    // Helper function to calculate exponential in a fixed-point format
    function exp(uint256 x) internal pure returns (uint256) {
        // x is expected to be in the fixed-point format with 18 decimal places
        // We use an approximation for e^x: exp(x) = sum(x^n / n!)
        // For simplicity and avoiding excessive gas cost, we'll approximate up to 6 terms

        uint256 term = x;
        uint256 result = 1 ether; // e^0 = 1
        result += term;

        term = (term * x) / 1 ether; // x^2 / 2!
        result += term / 2;

        term = (term * x) / 1 ether; // x^3 / 3!
        result += term / 6;

        term = (term * x) / 1 ether; // x^4 / 4!
        result += term / 24;

        term = (term * x) / 1 ether; // x^5 / 5!
        result += term / 120;

        term = (term * x) / 1 ether; // x^6 / 6!
        result += term / 720;

        return result;
    }


    // Function to buy tokens by specifying the ETH amount
    function buyWithETH(uint256 amount, uint256 maxSlippagePercent) external payable nonReentrant {
        

        if (liquiditySent) revert LiquidityAlreadySent();
        if (amount > maxBuy) revert ExceededMaxBuy(maxBuy);
        console.log('amount %d,ethPaid %d,targetMarketCap %d', amount ,ethPaid,targetMarketCap);
        console.log('amount + ethPaid %d,targetMarketCap %d', amount + ethPaid,targetMarketCap);
        if(amount + ethPaid>targetMarketCap) revert ExceedsMarketCap();
        
        uint256 fee = (amount * transactionFeePercent) / 10000;
        uint256 netAmount = amount + fee;// in ETH
        
        if (netAmount > msg.value) revert InsufficientETH(msg.value, netAmount);

        // Calculate the expected price per token (in ETH)
        uint256 totalEthInContractBefore = ethPaid;// address(this).balance - msg.value;
        // uint256 initialTokens = tokensIssued(totalEthInContractBefore);
        uint256 expectedPricePerToken = amount / calculateNumberOfTokensToBuy(amount);

        
        // Calculate the number of tokens expected for the given ETH amount
        uint256 tokensToBuy = calculateNumberOfTokensToBuy(ethPaid , amount);
        ethPaid+= amount;
        console.log('BUYWITHETH:: tokensToBuy %d, expectedPricePerToken: %d', tokensToBuy, expectedPricePerToken);
        // Check the token balance available for sale
        if (tokensToBuy > balanceOf(address(this))) revert InsufficientTokens(balanceOf(address(this)), tokensToBuy);

        

        // console.log('initialTokens %d, expectedPricePerToken: %d', initialTokens, expectedPricePerToken);
        uint currentTokenBalance = balanceOf(address(this));
        console.log('currentTokenBalance %d , tokensToBuy %d', currentTokenBalance, tokensToBuy);
        // Perform the token transfer and handle fees
        payable(feeAddress).transfer(fee);
        _transfer(address(this), msg.sender, tokensToBuy);
        netBoughtTokens += tokensToBuy; // Increase net bought tokens

        currentTokenBalance = balanceOf(address(this));
        console.log('currentTokenBalance after %d , tokensToBuy %d', currentTokenBalance, tokensToBuy);

        // Calculate the actual price per token after the transaction
        uint256 totalEthInContractAfter = ethPaid;// address(this).balance;
        // uint256 finalTokens = tokensIssued(totalEthInContractAfter);
        uint256 effectivePricePerToken = (totalEthInContractAfter - totalEthInContractBefore) / tokensToBuy;

        // console.log('finalTokens %d, effectivePricePerToken: %d', finalTokens, effectivePricePerToken);
        // Calculate the allowed slippage
        uint256 maxAllowedSlippage = (expectedPricePerToken * (10000  + maxSlippagePercent)) / 10000 ;
        // Ensure the effective price does not exceed the maximum allowed price with slippage
        // require(effectivePricePerToken <= maxAllowedSlippage, "Slippage too high");
        if (effectivePricePerToken > maxAllowedSlippage) {
            revert SlippageExceeded(effectivePricePerToken, maxAllowedSlippage);
        }

        // emit BoughtToken(msg.sender, amount);
        popCoinFactory.notifyTrade(msg.sender, address(this),0, tokensToBuy, amount );
        // console.log('amount/(finalTokens-initialTokens) %d, effectivePricePerToken: %d', amount/(finalTokens-initialTokens), effectivePricePerToken);
        // console.log('maxAllowedSlippage %d, expectedPricePerToken: %d', maxAllowedSlippage, effectivePricePerToken);
        // console.log('Real ETH BAl %d, targetMarketCap: %d', address(this).balance, targetMarketCap);

        // Deploy liquidity if the target market cap is reached

        console.log('address(this).balance %d , netBoughtTokens %d, ethPaid %d', address(this).balance, netBoughtTokens, ethPaid);
        if (address(this).balance >= targetMarketCap) {
            _sendLiquidity();
        }
    }

    
    // Function to buy tokens by specifying the amount of tokens to buy, send cost of buying  plus tx fee
    function buy(uint256 amount, uint256 maxSlippagePercent) external payable nonReentrant {
        if(liquiditySent) revert LiquidityAlreadySent();
        // uint256 pricePerToken = calculatePrice();
        
        uint256 totalCost = calculateNumberOfTokensToBuyWithTokens(ethPaid, amount); // in ETH

		uint256 fee = (totalCost * transactionFeePercent) / 10000; //in ETH
        uint256 netAmount = totalCost + fee;// in ETH

        if (totalCost > maxBuy) revert ExceededMaxBuy(maxBuy);

        if (msg.value < netAmount) revert InsufficientETH(msg.value, netAmount);        

        if (amount > balanceOf(address(this))) revert InsufficientTokens(balanceOf(address(this)), amount);

        uint256 initialCost = calculateNumberOfTokensToBuyWithTokens( amount); // in ETH;

		
        if (totalCost > initialCost * (10000 + maxSlippagePercent) / 10000) {
            revert SlippageExceeded(totalCost, initialCost);
        }

        payable(feeAddress).transfer(fee);
        _transfer(address(this), msg.sender, amount);

        ethPaid+= totalCost;
        netBoughtTokens += amount; // Increase net bought tokens
        // emit BoughtToken(msg.sender, amount);
        popCoinFactory.notifyTrade(msg.sender, address(this),0, amount, netAmount );

        // Refund any excess ETH sent
        if (msg.value > netAmount) {
            payable(msg.sender).transfer(msg.value - netAmount);
        }

        // Deploy liquidity if the target market cap is reached
        if (address(this).balance >= targetMarketCap) {
            _sendLiquidity();
        }
    }

    // Function to sell tokens by specifying the amount of tokens
    function sell(uint256 amount /*, uint maxSlippagePercent*/) external nonReentrant {
        if(liquiditySent) revert LiquidityAlreadySent();
        // uint256 pricePerToken = calculatePrice();
        uint256 totalReward = calculateNumberOfETHSoldForToken(amount); // pricePerToken * amount;

        if (address(this).balance < totalReward) revert InsufficientContractETH(address(this).balance, totalReward);

        uint256 fee = (totalReward * transactionFeePercent) / 10000;
        uint256 netReward = totalReward - fee;

		// uint256 finalPricePerToken = calculatePrice();
        // if (finalPricePerToken > pricePerToken * (10000 + maxSlippagePercent) / 10000) {
        //     revert SlippageExceeded(finalPricePerToken, pricePerToken * (10000 + maxSlippagePercent) / 10000);
        // }

        _transfer(msg.sender, address(this), amount);
        payable(feeAddress).transfer(fee);
        payable(msg.sender).transfer(netReward);
        console.log('netBoughtTokens: %d',netBoughtTokens);
        popCoinFactory.notifyTrade(msg.sender, address(this),1, amount, totalReward );
        ethPaid-= totalReward;
        netBoughtTokens -= amount; // Decrease net bought tokens

        
    }

    // // Function to sell tokens by specifying the ETH amount desired
    // function sellWithETH(uint256 amount, uint maxSlippagePercent/* x 100  */) external nonReentrant {
    //     if(liquiditySent) revert LiquidityAlreadySent();
    //     if (address(this).balance < amount) revert InsufficientContractETH(address(this).balance, amount);

    //     uint256 pricePerToken = calculatePrice();
    //     uint256 tokensToSell = amount / pricePerToken;

    //     uint256 totalReward = pricePerToken * tokensToSell;
    //     uint256 fee = (totalReward * transactionFeePercent) / 10000;
    //     uint256 netReward = totalReward - fee;

    //     if (balanceOf(msg.sender) < tokensToSell) revert BalanceExceeded(balanceOf(msg.sender), tokensToSell);

	// 	// Recalculate price to check slippage
    //     uint256 finalPricePerToken = calculatePrice();
    //     if (finalPricePerToken < pricePerToken * (10000 - maxSlippagePercent) / 10000) {
    //         revert SlippageExceeded(finalPricePerToken, pricePerToken * (10000 - maxSlippagePercent) / 10000);
    //     }

    //     _transfer(msg.sender, address(this), tokensToSell);
    //     payable(feeAddress).transfer(fee);
    //     payable(msg.sender).transfer(netReward);

    //     netBoughtTokens -= tokensToSell; // Decrease net bought tokens
    // }

	//Todo - Check calculations for tokenAmount
    // function _sendLiquidity() internal {
    //     if (!liquiditySent && address(this).balance >= targetMarketCap) {
    //         uint256 liquidityAmount = (address(this).balance * liquidityDeploymentPercent) / 10000;
	// 		uint256 tokenAmount = calculateNumberOfTokensToBuy(liquidityAmount);
    //         uint256 pricePerToken = calculateNumberOfTokensToBuy(1 ether);
	// 		// uint256 tokenAmount = pricePerToken * liquidityAmount ;

    //         console.log(
    //             "liq %d , pricePerToken %d tokenAmount %d tokens",
    //             liquidityAmount,
    //             pricePerToken,
    //             tokenAmount
    //         );

    //         IDexFactory factory = IDexFactory(v2Router.factory());
    //         address lpTokenPairAddress = factory.getPair(address(this), v2Router.WETH());
    //         if (lpTokenPairAddress == address(0)) {
    //             lpTokenPairAddress = factory.createPair(address(this), v2Router.WETH());
    //         }
            
	// 		_approve(address(this), address(v2Router), MAX_INT);//tokenAmount
    //         _approve(address(this), lpTokenPairAddress, MAX_INT);//tokenAmount

    //         // payable(routerAddress).transfer(liquidityAmount);

	// 		v2Router.addLiquidityETH{ value: liquidityAmount }(
	// 			address(this),
	// 			tokenAmount,    
	// 			0,
	// 			0,
	// 			feeAddress, //test
	// 			block.timestamp + 1200 //20 minutes from now
	// 		);

    //         liquiditySent=true;
    //     }
    // }

    function _sendLiquidity() internal {
        if (!liquiditySent && address(this).balance >= targetMarketCap) {
            
            //Send all remaining fund to liquidity
            uint256 liquidityAmount =  address(this).balance - deployLiquidityFee;

            payable(feeAddress).transfer(deployLiquidityFee);
            
            uint currentTokenBalance = balanceOf(address(this));

            //Mint 200m tokens to add
			uint256 tokenAmount = 200_000_000 ether;
            _mint(address(this), tokenAmount);
            
            console.log('currentTokenBalance %d , tokenAmount %d', currentTokenBalance, tokenAmount);
            console.log('new bal mint %d ', balanceOf(address(this)));
            if(currentTokenBalance>=0){//use balance if more than 200m
                tokenAmount+=currentTokenBalance;
            }

            uint256 pricePerToken = liquidityAmount/tokenAmount;
			// uint256 tokenAmount = pricePerToken * liquidityAmount ;

            console.log(
                "liq %d , pricePerToken %d tokenAmount %d tokens",
                liquidityAmount,
                pricePerToken,
                tokenAmount
            );

            IDexFactory factory = IDexFactory(v2Router.factory());
            address lpTokenPairAddress = factory.getPair(address(this), v2Router.WETH());
            if (lpTokenPairAddress == address(0)) {
                lpTokenPairAddress = factory.createPair(address(this), v2Router.WETH());
            }
            
			_approve(address(this), address(v2Router), MAX_INT);//tokenAmount
            _approve(address(this), lpTokenPairAddress, MAX_INT);//tokenAmount

            // payable(routerAddress).transfer(liquidityAmount);

			(,, uint256 liquidity) = v2Router.addLiquidityETH{ value: liquidityAmount }(
				address(this),
				tokenAmount,    
				0,
				0,
				address(this), // feeAddress, //test
				block.timestamp + 1200 //20 minutes from now
			);

            liquiditySent=true;

            //TODO: Burn LP Tokens
            // // Get the LP token (pair) address
            // address pair = factory.getPair(address(this), v2Router.WETH());
            // require(pair != address(0), "Pair not found");

            // console.log('inital pair address: %s, final pair: %s', lpTokenPairAddress, pair);

            

            // uint newBalance =IERC20(lpTokenPairAddress).balanceOf(address(this));

            // console.log('liquidity: %d, newBalance: %d', liquidity, newBalance);

            // Transfer the LP tokens to the burn address
            require(IERC20(lpTokenPairAddress).transfer(BURN_ADDRESS, liquidity), "Burn LP tokens failed");
        }
    }

	

	function withdraw(address payable _to, uint256 _amount) public onlyOwner {
        if(!liquiditySent){
            revert('LiqdtyUnsent');
        }
        require(_amount <= payable(address(this)).balance);
        safeTransferETH(_to, _amount);
    }

	function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{ value: value }(new bytes(0));
        require(success, "TransferHelper::safeTransferETH: ETH transfer failed");
    }

    // Fallback function to receive ETH
    receive() external payable {}
}

