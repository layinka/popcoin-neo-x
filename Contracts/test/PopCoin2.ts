import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers, getChainId, network } from "hardhat";
import { formatEther, formatUnits, parseEther, parseUnits } from "ethers/lib/utils";
import { TokenCreateInfoStruct } from "../typechain-types/contracts/V2/PopCoinFactoryV2";
import { PopCoinDeploymentParameters } from "../utils/deploy-parameters";
import { BigNumber } from "ethers";

describe("PopCoin2",  function () {
  const chainId=12227332; //force chain deployment parameters
  // getChainId().then((c)=>{
  //   chainId = +c
  //   console.log('chainid is ', c)
  // }).catch(err=>{
  //   console.error('error etting chain', err)
  // })
  // const chainId = +await getChainId().catch(err=> console.error('error etting chain', err))

  const initVirtualEthReserve = PopCoinDeploymentParameters[chainId]?.initVirtualEthReserve || 10;
  const createTokenFee = PopCoinDeploymentParameters[chainId]?.createTokenFee || 0.005;
  const deployLiquidityFee= PopCoinDeploymentParameters[chainId]?.deployLiquidityFee || 1.5
  const transactionFeePercent_x_100 = PopCoinDeploymentParameters[chainId]?.transactionFeePercent_x_100 || 100; //1% is 1* 100
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployPopCoinfactoryFixture() {
    
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await hre.ethers.getSigners();

    const factory = await (await hre.ethers.getContractFactory("PancakeFactory")).deploy(owner.address);
  
    const weth = await (await hre.ethers.getContractFactory("WBNB")).deploy() 
  
    const router = await (await hre.ethers.getContractFactory("PancakeRouter")).deploy(factory.address, weth.address) 

    const PopCoinFactoryArtifact = await hre.ethers.getContractFactory("PopCoinFactoryV2");
    const popcoin = await PopCoinFactoryArtifact.deploy(  
      parseEther(initVirtualEthReserve.toString()) ,
      parseEther(createTokenFee.toString()) ,
      parseEther(deployLiquidityFee.toString()) ,
      transactionFeePercent_x_100 ,
      [router.address, ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.AddressZero], 
      {  }
    );

    await (await popcoin.changeAdminPaymentAddress('0x4725323e0497F508ECF859d1F7d15bF43aF8c1e2')).wait();
    return { popcoin, owner, otherAccount , router};
  }

  describe("Deployment", function () {
    it("Should deploy a new Token", async function () {
      
      const { popcoin,owner, router } = await loadFixture(deployPopCoinfactoryFixture);
      const initialBuy = parseEther('0.5') 
      const createFee = parseEther(createTokenFee.toString()) 
      const t:TokenCreateInfoStruct = {
        banner: 'https://placehold.it/360',
        logo: 'https://placehold.it/360',
        description:'description descruption description',
        initialCreatorBuy: initialBuy,
        name: 'TKN A',
        symbol: 'TKNA',
        routerAddress: router.address,
        telegram:'https://t.me/tokenaaa',
        twitter:'https://x.me/tokenaaa',
        website:'www.wwwwwww.com',
      
      }
      
      const tx = await popcoin.createToken(t, {value: initialBuy.add(createFee)});
      const txReceipt = await tx.wait();

      console.log('popcoin: ', popcoin.address)

      

      expect(txReceipt.status).to.equal(1);
      const tokenAddress = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['tokenAddress'];
      const tokenCreator = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['creator'];
      console.log('TokenAddress: ', tokenAddress );

      let pool = await popcoin.tokenPool(tokenAddress)
      let mcap2 = pool.ethReserve +  (pool.lastPrice * await popcoin.INIT_VIRTUAL_TOKEN_RESERVE() )
      

      expect(tokenAddress).to.not.equal(undefined);
      expect(tokenCreator).to.equal(owner.address);

      const funToken = await hre.ethers.getContractAt("FunTokenV2", tokenAddress)

      console.log('Name : ',(await  funToken.name()) )

      expect(await  funToken.name()).to.equal(t.name);

      
    });

    it("Should buy successfully", async function () {
      const { popcoin,owner,router } = await loadFixture(deployPopCoinfactoryFixture);
      const t:TokenCreateInfoStruct = {
        banner: 'https://placehold.it/360',
        logo: 'https://placehold.it/360',
        description:'description descruption description',
        initialCreatorBuy: parseEther('0'),
        name: 'TKN A',
        symbol: 'TKNA',
        routerAddress: router.address,
        telegram:'https://t.me/tokenaaa',
        twitter:'https://x.me/tokenaaa',
        website:'www.wwwwwww.com',
      
      }
      const tx = await popcoin.createToken(t, {value: parseEther(createTokenFee.toString())});
      const txReceipt = await tx.wait();

      const tokenAddress = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['tokenAddress'];
      const tokenCreator = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['creator'];
      

      expect(tokenAddress).to.not.equal(undefined);
      expect(tokenCreator).to.equal(owner.address);

      const funToken = await hre.ethers.getContractAt("FunToken", tokenAddress)

      const adminPaymentAddress =  await popcoin.adminPaymentAddress();
      const initialAdminEthBalance = await hre.ethers.provider.getBalance(adminPaymentAddress);
      const initialEthBalance = await hre.ethers.provider.getBalance(owner.address)
      const initialBalance = formatEther(await  funToken.balanceOf(owner.address))
      

      let ethIn =  parseEther('0.1') 
      let tokenOutMin = await popcoin.calcAmountOutFromEth(tokenAddress,  ethIn );
      
      let txBuy = await popcoin.swapEthForTokens(tokenAddress, ethIn, tokenOutMin, new Date().getTime() + 120000, {value: ethIn});
      let txBuyReceipt = await txBuy.wait();

            
      expect(txBuyReceipt.status).to.equal(1);

      const endAdminEthBalance = await hre.ethers.provider.getBalance(adminPaymentAddress);
      const endEthBalance = await hre.ethers.provider.getBalance(owner.address)
      const endBalance = formatEther(await  funToken.balanceOf(owner.address))
      
      expect(+endBalance).greaterThan(+initialBalance)
      expect(+formatEther(endAdminEthBalance) - +formatEther(initialAdminEthBalance)).gte( +formatEther(ethIn.mul(9).div(10).mul( transactionFeePercent_x_100).div(10000))) //mply by 0.9 (.mul(9).div(10)) cos of rounding error
      expect(+formatEther(initialEthBalance) - +formatEther(endEthBalance)).gte( +formatEther(ethIn))
    });

    it("Should sell successfully", async function () {
      const { popcoin,owner,router } = await loadFixture(deployPopCoinfactoryFixture);
      const t:TokenCreateInfoStruct = {
        banner: 'https://placehold.it/360',
        logo: 'https://placehold.it/360',
        description:'description descruption description',
        initialCreatorBuy: parseEther('0'),
        name: 'TKN A',
        symbol: 'TKNA',
        routerAddress: router.address,
        telegram:'https://t.me/tokenaaa',
        twitter:'https://x.me/tokenaaa',
        website:'www.wwwwwww.com',
      
      }
      const tx = await popcoin.createToken(t, {value: parseEther(createTokenFee.toString())});
      const txReceipt = await tx.wait();

      const tokenAddress = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['tokenAddress'];
      const tokenCreator = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['creator'];
      

      expect(tokenAddress).to.not.equal(undefined);
      expect(tokenCreator).to.equal(owner.address);

      const funToken = await hre.ethers.getContractAt("FunToken", tokenAddress)

      let ethIn =  parseEther('0.2') 
      let tokenOutMin = await popcoin.calcAmountOutFromEth(tokenAddress,  ethIn );      
      let txBuy = await popcoin.swapEthForTokens(tokenAddress, ethIn, tokenOutMin, new Date().getTime() + 120000, {value: ethIn});
      let txBuyReceipt = await txBuy.wait();

      const adminPaymentAddress =  await popcoin.adminPaymentAddress();
      const initialAdminEthBalance = await hre.ethers.provider.getBalance(adminPaymentAddress);
      const initialEthBalance = await hre.ethers.provider.getBalance(owner.address)
      const initialBalance = formatEther(await  funToken.balanceOf(owner.address))
      

      let tokenIn =  parseEther((+initialBalance / 2).toString()) 
      let ethOutMin = await popcoin.calcAmountOutFromToken(tokenAddress,  tokenIn );

      const txApproveBuy = await (await funToken.approve(popcoin.address, tokenIn)).wait();
      

      let txSell = await popcoin.swapTokensForEth(tokenAddress, tokenIn, ethOutMin, new Date().getTime() + 120000, {});
      let txSellReceipt = await txSell.wait();

            
      expect(txSellReceipt.status).to.equal(1);

      const endAdminEthBalance = await hre.ethers.provider.getBalance(adminPaymentAddress);
      const endEthBalance = await hre.ethers.provider.getBalance(owner.address)
      const endBalance = formatEther(await  funToken.balanceOf(owner.address))
  
      expect(endEthBalance).greaterThan(initialEthBalance)
      expect(+formatEther(endAdminEthBalance) - +formatEther(initialAdminEthBalance)).gte( (0.99 * transactionFeePercent_x_100/10000) * +formatEther(ethOutMin) )//0.009 or rounding errors
      expect(+initialBalance - +endBalance).gte(+formatEther( tokenIn))

    });

    it("Should migrate liquidity successfully when target mcap is reached", async function () {
      
      const { popcoin,owner, router } = await loadFixture(deployPopCoinfactoryFixture);
      const initialBuy = parseEther('0.5') 
      const createFee = parseEther(createTokenFee.toString()) 
      const t:TokenCreateInfoStruct = {
        banner: 'https://placehold.it/360',
        logo: 'https://placehold.it/360',
        description:'description descruption description',
        initialCreatorBuy: initialBuy,
        name: 'TKN A',
        symbol: 'TKNA',
        routerAddress: router.address,
        telegram:'https://t.me/tokenaaa',
        twitter:'https://x.me/tokenaaa',
        website:'www.wwwwwww.com',
      
      }
      
      const tx = await popcoin.createToken(t, {value: initialBuy.add(createFee)});
      const txReceipt = await tx.wait();

      //console.log('popcoin: ', popcoin.address)

      

      expect(txReceipt.status).to.equal(1);
      const tokenAddress = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['tokenAddress'];
      const tokenCreator = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['creator'];
      // console.log('TokenAddress: ', tokenAddress );

      // console.log('popcoin migrationThreshold: ',formatEther( await popcoin.migrationThreshold() ))
      // console.log('popcoin ethReserve: ',formatEther( (await popcoin.tokenPool(tokenAddress)).ethReserve) )
      // console.log('popcoin tokenReserve: ',formatEther( (await popcoin.tokenPool(tokenAddress)).tokenReserve) )

      // console.log('popcoin lastPrice: ',formatEther( (await popcoin.tokenPool(tokenAddress)).lastPrice) )
      // console.log('popcoin mcap: ',formatEther( (await popcoin.tokenPool(tokenAddress)).lastMcapInEth) )

      let pool = await popcoin.tokenPool(tokenAddress)
      let mcap2 = pool.ethReserve +  (pool.lastPrice * await popcoin.INIT_VIRTUAL_TOKEN_RESERVE() )
      if(mcap2.toString().indexOf('.')>-1){
        mcap2 = BigInt(mcap2.toString().substring(0,mcap2.toString().indexOf('.')));
      }
      // console.log('popcoin mcap 2: ',mcap2 )
      // console.log('popcoin mcap 2 2: ', mcap2.toString().substring(0,mcap2.toString().indexOf('.')) )
      // console.log('popcoin mcap 2 2: ',BigInt(mcap2.toString().substring(0,mcap2.toString().indexOf('.'))) )
      
      // console.log('popcoin mcap 2 3: ',formatEther( mcap2 ))

      expect(tokenAddress).to.not.equal(undefined);
      expect(tokenCreator).to.equal(owner.address);

      const funToken = await hre.ethers.getContractAt("FunTokenV2", tokenAddress)
      const initialTokenBalance = await  funToken.balanceOf(owner.address)
      // console.log('FunToken initialTokenBalance : ',formatEther(initialTokenBalance) )
      
      let amountToTriggerMigrate = BigNumber.from(await popcoin.migrationThreshold()).sub(BigNumber.from( (await popcoin.tokenPool(tokenAddress)).ethReserve)) ;
      console.log('amountToTriggerMigrate : ',formatUnits(amountToTriggerMigrate.toString(), 18) ) 
      // let ethIn = amountToTriggerMigrate.add (amountToTriggerMigrate.mul(transactionFeePercent_x_100).div(10000) );// parseEther('28.335119685602000715') 
      let tmp = BigNumber.from(parseEther('1')).sub( BigNumber.from( transactionFeePercent_x_100).div(10000))
      console.log('TMP : ',formatEther(tmp), tmp )
      let ethIn =parseEther( ( +formatEther( amountToTriggerMigrate) / (1 - ((transactionFeePercent_x_100+2)/10000) )).toString()) ;// parseEther('28.335119685602000715') 
      let tokenOutMin = await popcoin.calcAmountOutFromEth(tokenAddress,  ethIn );

      const tokenNeededForMigrate = BigNumber.from(await popcoin.INIT_REAL_TOKEN_RESERVE()).sub( initialTokenBalance);
      
      console.log('FunToken tokenNeededForMigrate : ',formatEther(tokenNeededForMigrate.toString()) )

      let ethNeededForTokenMigrate = await popcoin.calcAmountOutFromToken(tokenAddress,tokenNeededForMigrate);
      console.log('FunToken ethNeededForTokenMigrate : ',formatEther(ethNeededForTokenMigrate) )


      console.log('ethIn: ',formatEther(ethIn)  ,'migrationThreshold : ',formatEther(await popcoin.migrationThreshold()) )
      
      console.log('tokenOutMin : ',formatEther(tokenOutMin) )


      //Gift enough coins
      await network.provider.send("hardhat_setBalance", [
        owner.address,//<ACCOUNT ADDRESS>
        "0x" + (1e6 * 1e18).toString(16), // 1 million ETH in wei (1e6 * 1e18 wei/ETH), //# 1,000,000 wei
      ]);
      
      let txBuy = await popcoin.swapEthForTokens(tokenAddress, ethIn, tokenOutMin, new Date().getTime() + 120000, {value: ethIn});
      let txBuyReceipt = await txBuy.wait();

      const endBalance = formatEther(await  funToken.balanceOf(owner.address))
      pool = await popcoin.tokenPool(tokenAddress);

      console.log('is migrated: ', pool.migrated)

      console.log('Final token balance: ', endBalance)




      // expect(await hre.ethers.provider.getBalance(tokenAddress)).to.equal(
      //   parseEther('1').toBigInt()
      // );
    });

    // it("Price calc", async function () {
    //   const { popcoin,owner, router } = await loadFixture(deployPopCoinfactoryFixture);
      
    //   const maxThreshold = parseEther('0.0003');
    //   console.log('migrationThreshold', (await popcoin.migrationThreshold()))
    //   console.log('migrationThreshold', formatEther(await popcoin.migrationThreshold()))

    //   const t:TokenCreateInfoStruct = {
    //     banner: 'https://placehold.it/360',
    //     logo: 'https://placehold.it/360',
    //     description:'description descruption description',
    //     initialCreatorBuy: parseEther('0'),
    //     name: 'TKN A',
    //     symbol: 'TKNA',
    //     routerAddress: router.address,
    //     telegram:'https://t.me/tokenaaa',
    //     twitter:'https://x.me/tokenaaa',
    //     website:'www.wwwwwww.com',
      
    //   }
      
    //   const tx = await popcoin.createToken(t, {value: parseEther('1.0005')});
    //   const txReceipt = await tx.wait();

    //   const tokenAddress = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['tokenAddress'];
    //   const tokenCreator = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['creator'];
    //   console.log('TokenAddress: ', tokenAddress, ', balabce: ', await hre.ethers.provider.getBalance(tokenAddress) );

      

    //   expect(tokenAddress).to.not.equal(undefined);
    //   expect(tokenCreator).to.equal(owner.address);

    //   const funToken = await hre.ethers.getContractAt("FunTokenV2", tokenAddress)

    //   console.log('balance1 : ',formatEther(await  funToken.balanceOf(owner.address)) )


    //   let amountOfTokensIn = parseEther('100')
    //   let amt_r = await popcoin.calcAmountOutFromToken(tokenAddress, amountOfTokensIn);
    //   console.log(formatEther(amountOfTokensIn), ' Tokens -> ', formatEther( amt_r.amountOut)+' ETH ' )

    //   let max = 2.833511968560200071;
    //   let fee = 0.1 * max
    //   let amountIn = parseEther((max+fee).toString())
    //   amt_r = await popcoin.calcAmountOutFromEth(tokenAddress, amountIn);
    //   console.log('Tokens for  : ', formatEther(amountIn), formatEther( amt_r.amountOut) )

    //   let amt = 0.000001;
    //   fee = 0.1 * amt
    //   amountIn = parseEther((amt+fee).toString())
    //   amt_r = await popcoin.calcAmountOutFromEth(tokenAddress, amountIn);
    //   console.log('Tokens for  : ', formatEther(amountIn), formatEther( amt_r.amountOut) )

    //   amt = 0.00001;
    //   fee = 0.1 * amt
    //   console.log((amt+fee).toFixed(18))
    //   amountIn = parseEther((amt+fee).toFixed(18))
    //   amt_r = await popcoin.calcAmountOutFromEth(tokenAddress, amountIn);
    //   console.log('Tokens for  : ', formatEther(amountIn), formatEther( amt_r.amountOut) )

    //   amt = 0.0001;
    //   fee = 0.1 * amt
    //   amountIn = parseEther((amt+fee).toFixed(18))
    //   amt_r = await popcoin.calcAmountOutFromEth(tokenAddress, amountIn);
    //   console.log('Tokens for  : ', formatEther(amountIn), formatEther( amt_r.amountOut) )

    //   amt = 0.001;
    //   fee = 0.1 * amt
    //   amountIn = parseEther((amt+fee).toFixed(18))
    //   amt_r = await popcoin.calcAmountOutFromEth(tokenAddress, amountIn);
    //   console.log('Tokens for  : ', formatEther(amountIn), formatEther( amt_r.amountOut) )

    //   amt = 0.00001;
    //   const amounts = [
    //     0.00001,
    //     0.0001,
    //     0.001,
    //     0.01,
    //     0.1,
    //     1,
    //     1.2,
    //     1.5,
    //     2, 
    //     2.5
    //   ]
    //   for (let i = 0; i < amounts.length; i++) {
    //     amt = amounts[i];
    //     fee = 0.1 * amt
    //     amountIn = parseEther((amt+fee).toFixed(18))
    //     amt_r = await popcoin.calcAmountOutFromEth(tokenAddress, amountIn);
    //     console.log('', amt,',', formatEther( amt_r.amountOut) )
        
    //   }

    //   let l =  parseEther('0.11') 
    //   let lOut = await popcoin.calcAmountOutFromEth(tokenAddress,  parseEther('0.1') );
    //   console.log('l', l, lOut)
    //   let txBuy = await popcoin.swapEthForTokens(tokenAddress, l, lOut.amountOut, new Date().getTime() + 120000, {value: l});
    //   let txBuyReceipt = await txBuy.wait();

    //   const tradedEventArgs = txBuyReceipt.events.filter((f: any)=>f.event=='TokenTraded')[0].args//['creator'];
    //   console.log('tradedEventArgs: ',tradedEventArgs)
      
    //   // console.log('migrationThreshold', formatEther(await popcoin.migrationThreshold()))

    //   // console.log( ' ethReserver: ', formatEther((await popcoin.tokenPool(tokenAddress)).ethReserve))
            
    //   // console.log('New balance1 : ',formatEther(await  funToken.balanceOf(owner.address)) )


    //   // txBuy = await funToken.buyWithETH(parseEther('0.11'), '10000', {value: parseEther('0.1111')});
    //   // txBuyReceipt = await txBuy.wait();

    //   // console.log('Token balance : ',formatEther(await  funToken.balanceOf(owner.address)) )

    //   // console.log('ETH to sell 1,000,000 : ', formatEther( await funToken["calculateNumberOfETHSoldForToken(uint256)"]( parseEther('1000000') )) )

    //   // console.log('ETH to sell 10,000,000 : ', formatEther( await funToken["calculateNumberOfETHSoldForToken(uint256)"]( parseEther('10000000') )) )

    //   // console.log('ETH to sell 22990004.0 : ', formatEther( await funToken["calculateNumberOfETHSoldForToken(uint256)"]( parseEther('22990004') )) )

      

    //   // // console.log('Tokens for 1 ETH : ',  await funToken.calculateNumberOfTokensToBuy( parseEther('1') ))
      
    //   // // // funToken["calculatePrice()"].call()
    //   // // // funToken.calculateTokensForETH(1)
    //   // // console.log('Tokens for 2 ETH : ',  await funToken["tokensIssued(uint256)"](parseEther('2')))

    //   // // console.log('Price for 2 ETH : ',formatEther( await funToken["priccee(uint256)"](parseEther('2'))) )

    //   // // console.log('Price for 10 ETH : ',formatEther( await funToken["tokensIssued(uint256)"](parseEther('10'))))

    //   // // console.log('Price for 10 ETH : ',formatEther( await funToken["tokensIssued(uint256)"](parseEther('30'))))

    //   // // console.log('Price for 10 ETH : ',formatEther( await funToken["tokensIssued(uint256)"](parseEther('50'))))




    //   // // console.log('Price for 1 ETH : ', await funToken["calculatePrice(uint256)"](parseEther('1')))

    //   // // console.log('Price for 2 ETH : ', await funToken["calculatePrice(uint256)"](parseEther('2')))

    //   // // console.log('Price for 10 ETH : ', await funToken["calculatePrice(uint256)"](parseEther('10')))

    // });

    // it("Price calc2", async function () {
    //   let { owner, router } = await loadFixture(deployPopCoinfactoryFixture);
    //   let popcoin= await hre.ethers.getContractAt("PopCoinFactoryV2", "0x8A791620dd6260079BF849Dc5567aDC3F2FdC318");
    //   const maxThreshold = parseEther('0.0003');
    //   console.log('migrationThreshold', (await popcoin.migrationThreshold()))
    //   console.log('migrationThreshold', formatEther(await popcoin.migrationThreshold()))

    //   const t:TokenCreateInfoStruct = {
    //     banner: 'https://placehold.it/360',
    //     logo: 'https://placehold.it/360',
    //     description:'description descruption description',
    //     initialCreatorBuy: parseEther('0.1'),
    //     name: 'TKN B',
    //     symbol: 'TKNB',
    //     routerAddress: router.address,
    //     telegram:'https://t.me/tokenaaa',
    //     twitter:'https://x.me/tokenaaa',
    //     website:'www.wwwwwww.com',
      
    //   }
      
    //   const tx = await popcoin.createToken(t, {value: parseEther('0.1105')});
    //   const txReceipt = await tx.wait();

    //   const tokenAddress = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['tokenAddress'];
    //   const tokenCreator = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['creator'];
    //   console.log('TokenAddress: ', tokenAddress, ', balabce: ', await hre.ethers.provider.getBalance(tokenAddress) );

    //   const tokenCreatedEventArgs = txReceipt.events.filter((f: any)=>f.event=='TokenTraded')[0].args//['creator'];
    //   console.log('tokenCreatedEventArgs: ',tokenCreatedEventArgs)

    //   expect(tokenAddress).to.not.equal(undefined);
    //   expect(tokenCreator).to.equal(owner.address);

    //   const funToken = await hre.ethers.getContractAt("FunTokenV2", tokenAddress)

    //   console.log('balance1 : ',formatEther(await  funToken.balanceOf(owner.address)) )


    //   let max = 2.833511968560200071;
    //   let fee = 0.1 * max
      

    //   // let l =  parseEther('0.11') 
    //   // let lOut = await popcoin.calcAmountOutFromEth(tokenAddress,  parseEther('0.1') );
    //   // console.log('l', l, lOut)
    //   // let txBuy = await popcoin.swapEthForTokens(tokenAddress, l, lOut.amountOut, new Date().getTime() + 120000, {value: l});
    //   // let txBuyReceipt = await txBuy.wait();

    //   // const tradedEventArgs = txBuyReceipt.events.filter((f: any)=>f.event=='TokenTraded')[0].args//['creator'];
    //   // console.log('tradedEventArgs: ',tradedEventArgs)
      
    // });


    // it("Should add liquidity successfully if targetMarketCap hit", async function () {
    //   const { popcoin,owner,router } = await loadFixture(deployPopCoinfactoryFixture);
    //   const tx = await popcoin.createToken('TKN A', 'TKNA', parseEther('1'),router.address, {value: parseEther('1.001')});
    //   const txReceipt = await tx.wait();



    //   const tokenAddress = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['tokenAddress'];
    //   const tokenCreator = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['creator'];
    //   console.log('TokenAddress: ', tokenAddress, ', balabce: ', await hre.ethers.provider.getBalance(tokenAddress) );

      

    //   expect(tokenAddress).to.not.equal(undefined);
    //   expect(tokenCreator).to.equal(owner.address);

    //   const funToken = await hre.ethers.getContractAt("FunToken", tokenAddress)

    //   let txBuy = await funToken.buyWithETH(parseEther('1'), '10000', {value: parseEther('1.01')});
    //   let txBuyReceipt = await txBuy.wait();

    //   // console.log('txbuy: ', txBuyReceipt)
      
    //   expect(txBuyReceipt.status).to.equal(1);
      
    //   console.log('Balance 2: ', tokenAddress, ', balance: ', formatEther( await hre.ethers.provider.getBalance(tokenAddress) ) );

    //   // txBuy = await funToken.buyWithETH(parseEther('0.01'), '100', {value: parseEther('0.011')});
    //   // txBuyReceipt = await txBuy.wait();
      
      
    //   let priceFor1000 = await funToken["calculateNumberOfTokensToBuyWithTokens(uint256)"](parseEther('34612000'));
    //   console.log('priceFor1000: ', priceFor1000, ', formatted priceFor1000: ', formatEther(priceFor1000) );
    //   const percentdivisor = BigInt(100n)
      
    //   priceFor1000 = BigInt(priceFor1000) + BigInt ( priceFor1000) / BigInt(percentdivisor)
    //   txBuy = await funToken.buy(parseEther('34612000'), '100000', {value:  priceFor1000 });
    //   txBuyReceipt = await txBuy.wait();

    //   console.log('buy with token finished: ' );

    //   const tokensToBuy = 5;
    //   const tokensToBuyWithFees = tokensToBuy + ( (1/100)* tokensToBuy);

    //   txBuy = await funToken.buyWithETH(parseEther(tokensToBuy.toString()), '10000', {value: parseEther(tokensToBuyWithFees.toString())});
    //   txBuyReceipt = await txBuy.wait();

    //   txBuy = await funToken.buyWithETH(parseEther(tokensToBuy.toString()), '10000', {value: parseEther(tokensToBuyWithFees.toString())});
    //   txBuyReceipt = await txBuy.wait();

    //   txBuy = await funToken.buyWithETH(parseEther(tokensToBuy.toString()), '10000', {value: parseEther(tokensToBuyWithFees.toString())});
    //   txBuyReceipt = await txBuy.wait();

    //   let liqSent = await funToken.liquiditySent();
    //   expect(liqSent).equal(false);

    //   txBuy = await funToken.buyWithETH(parseEther(tokensToBuy.toString()), '10000', {value: parseEther(tokensToBuyWithFees.toString())});
    //   txBuyReceipt = await txBuy.wait();

    //   txBuy = await funToken.buyWithETH(parseEther(tokensToBuy.toString()), '10000', {value: parseEther(tokensToBuyWithFees.toString())});
    //   txBuyReceipt = await txBuy.wait();

      

    //   let netBoughtTokens = formatEther( await funToken.netBoughtTokens());
    //   console.log('netBoughtTokens', netBoughtTokens)

    //   let ethPaid = await funToken.ethPaid();
    //   console.log('ethPaid', formatEther(ethPaid))

    //   let toPay =  BigInt(parseEther('30').toBigInt()) - BigInt(ethPaid);
    //   console.log('toPay', formatEther(toPay))

    //   txBuy = await funToken.buyWithETH(toPay, '10000', {value: toPay + (BigInt(1) * toPay/ BigInt(100) )});
    //   txBuyReceipt = await txBuy.wait();

    //   liqSent = await funToken.liquiditySent();
    //   expect(liqSent).equal(true);

    

     

    //   // // // console.log('txbuy: ', txBuyReceipt)

    //   // // console.log('Balance 3: ', tokenAddress, ', balabce: ', formatEther( await hre.ethers.provider.getBalance(tokenAddress)) );
      
    //   // // expect(txBuyReceipt.status).to.equal(1);
    // });

    
  });

  
});
