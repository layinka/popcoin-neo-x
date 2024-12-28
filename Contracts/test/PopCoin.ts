import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers } from "hardhat";
import { formatEther, parseEther } from "ethers/lib/utils";

describe("PopCoin", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployPopCoinfactoryFixture() {
    
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await hre.ethers.getSigners();

    const factory = await (await hre.ethers.getContractFactory("PancakeFactory")).deploy(owner.address);
  
    const weth = await (await hre.ethers.getContractFactory("WBNB")).deploy() 
  
    const router = await (await hre.ethers.getContractFactory("PancakeRouter")).deploy(factory.address, weth.address) 

    const PopCoinFactoryArtifact = await hre.ethers.getContractFactory("PopCoinFactory");
    const popcoin = await PopCoinFactoryArtifact.deploy([router.address, ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.AddressZero], {  });

    return { popcoin, owner, otherAccount , router};
  }

  describe("Deployment", function () {
    it("Should deploy a new Token", async function () {
      const { popcoin,owner, router } = await loadFixture(deployPopCoinfactoryFixture);
      const tx = await popcoin.createToken('TKN A', 'TKNA', parseEther('1'),router.address, {value: parseEther('1.001')});
      const txReceipt = await tx.wait();

      // console.log('txreceipt: ', txReceipt)

      expect(txReceipt.status).to.equal(1);
      const tokenAddress = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['tokenAddress'];
      const tokenCreator = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['creator'];
      console.log('TokenAddress: ', tokenAddress );

      expect(tokenAddress).to.not.equal(undefined);
      expect(tokenCreator).to.equal(owner.address);

      expect(await hre.ethers.provider.getBalance(tokenAddress)).to.equal(
        parseEther('1').toBigInt()
      );
    });

    it("Should buy successfully", async function () {
      const { popcoin,owner,router } = await loadFixture(deployPopCoinfactoryFixture);
      const tx = await popcoin.createToken('TKN A', 'TKNA', parseEther('1'),router.address, {value: parseEther('1.001')});
      const txReceipt = await tx.wait();

      const tokenAddress = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['tokenAddress'];
      const tokenCreator = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['creator'];
      console.log('TokenAddress: ', tokenAddress );

      expect(tokenAddress).to.not.equal(undefined);
      expect(tokenCreator).to.equal(owner.address);

      const funToken = await hre.ethers.getContractAt("FunToken", tokenAddress)

      const txBuy = await funToken.buyWithETH(parseEther('0.1'), '200', {value: parseEther('1.01')});
      const txBuyReceipt = await txBuy.wait();

      // console.log('txbuy: ', txBuyReceipt)
      
      expect(txBuyReceipt.status).to.equal(1);

    });

    it("Should sell successfully", async function () {
      const { popcoin,owner,router } = await loadFixture(deployPopCoinfactoryFixture);
      const tx = await popcoin.createToken('TKN A', 'TKNA', parseEther('1'),router.address, {value: parseEther('1.001')});
      const txReceipt = await tx.wait();

      const tokenAddress = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['tokenAddress'];
      const tokenCreator = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['creator'];
      console.log('TokenAddress: ', tokenAddress );

      expect(tokenAddress).to.not.equal(undefined);
      expect(tokenCreator).to.equal(owner.address);

      const funToken = await hre.ethers.getContractAt("FunToken", tokenAddress)
      console.log('balance1 : ',formatEther(await  funToken.balanceOf(owner.address)) )

      // const txBuy = await funToken.buyWithETH(parseEther('0.1'), '200', {value: parseEther('1.01')});
      // const txBuyReceipt = await txBuy.wait();

      // // console.log('txbuy: ', txBuyReceipt)
      
      // expect(txBuyReceipt.status).to.equal(1);

      console.log('formatted', formatEther('999999992400872927'))
      console.log('formatted 2', formatEther('1311723347'))

      funToken.approve(tokenAddress,parseEther('1000000000'))

      const txSell = await funToken.sell(parseEther('1'));
      const txSellReceipt = await txSell.wait();

      // console.log('txSellReceipt: ', txSellReceipt)
      
      expect(txSellReceipt.status).to.equal(1);

    });

    it("Price calc", async function () {
      const { popcoin,owner,router } = await loadFixture(deployPopCoinfactoryFixture);
      const tx = await popcoin.createToken('TKN A', 'TKNA', parseEther('0.12'),router.address, {value: parseEther('0.121')});
      const txReceipt = await tx.wait();



      const tokenAddress = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['tokenAddress'];
      const tokenCreator = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['creator'];
      console.log('TokenAddress: ', tokenAddress, ', balabce: ', await hre.ethers.provider.getBalance(tokenAddress) );

      

      expect(tokenAddress).to.not.equal(undefined);
      expect(tokenCreator).to.equal(owner.address);

      const funToken = await hre.ethers.getContractAt("FunToken", tokenAddress)

      console.log('balance1 : ',formatEther(await  funToken.balanceOf(owner.address)) )

      console.log('Tokens for 0.11 ETH : ', formatEther( await funToken["calculateNumberOfTokensToBuy(uint256)"]( parseEther('0.11') )) )

      let txBuy = await funToken.buyWithETH(parseEther('0.11'), '10000', {value: parseEther('0.1111')});
      let txBuyReceipt = await txBuy.wait();

      console.log('Token balance : ',formatEther(await  funToken.balanceOf(owner.address)) )

      console.log('ETH to sell 1,000,000 : ', formatEther( await funToken["calculateNumberOfETHSoldForToken(uint256)"]( parseEther('1000000') )) )

      console.log('ETH to sell 10,000,000 : ', formatEther( await funToken["calculateNumberOfETHSoldForToken(uint256)"]( parseEther('10000000') )) )

      console.log('ETH to sell 22990004.0 : ', formatEther( await funToken["calculateNumberOfETHSoldForToken(uint256)"]( parseEther('22990004') )) )

      

      // console.log('Tokens for 1 ETH : ',  await funToken.calculateNumberOfTokensToBuy( parseEther('1') ))
      
      // // funToken["calculatePrice()"].call()
      // // funToken.calculateTokensForETH(1)
      // console.log('Tokens for 2 ETH : ',  await funToken["tokensIssued(uint256)"](parseEther('2')))

      // console.log('Price for 2 ETH : ',formatEther( await funToken["priccee(uint256)"](parseEther('2'))) )

      // console.log('Price for 10 ETH : ',formatEther( await funToken["tokensIssued(uint256)"](parseEther('10'))))

      // console.log('Price for 10 ETH : ',formatEther( await funToken["tokensIssued(uint256)"](parseEther('30'))))

      // console.log('Price for 10 ETH : ',formatEther( await funToken["tokensIssued(uint256)"](parseEther('50'))))




      // console.log('Price for 1 ETH : ', await funToken["calculatePrice(uint256)"](parseEther('1')))

      // console.log('Price for 2 ETH : ', await funToken["calculatePrice(uint256)"](parseEther('2')))

      // console.log('Price for 10 ETH : ', await funToken["calculatePrice(uint256)"](parseEther('10')))

    });


    it("Should add liquidity successfully if targetMarketCap hit", async function () {
      const { popcoin,owner,router } = await loadFixture(deployPopCoinfactoryFixture);
      const tx = await popcoin.createToken('TKN A', 'TKNA', parseEther('1'),router.address, {value: parseEther('1.001')});
      const txReceipt = await tx.wait();



      const tokenAddress = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['tokenAddress'];
      const tokenCreator = txReceipt.events.filter((f: any)=>f.event=='TokenCreated')[0].args['creator'];
      console.log('TokenAddress: ', tokenAddress, ', balabce: ', await hre.ethers.provider.getBalance(tokenAddress) );

      

      expect(tokenAddress).to.not.equal(undefined);
      expect(tokenCreator).to.equal(owner.address);

      const funToken = await hre.ethers.getContractAt("FunToken", tokenAddress)

      let txBuy = await funToken.buyWithETH(parseEther('1'), '10000', {value: parseEther('1.01')});
      let txBuyReceipt = await txBuy.wait();

      // console.log('txbuy: ', txBuyReceipt)
      
      expect(txBuyReceipt.status).to.equal(1);
      
      console.log('Balance 2: ', tokenAddress, ', balance: ', formatEther( await hre.ethers.provider.getBalance(tokenAddress) ) );

      // txBuy = await funToken.buyWithETH(parseEther('0.01'), '100', {value: parseEther('0.011')});
      // txBuyReceipt = await txBuy.wait();
      
      
      let priceFor1000 = await funToken["calculateNumberOfTokensToBuyWithTokens(uint256)"](parseEther('34612000'));
      console.log('priceFor1000: ', priceFor1000, ', formatted priceFor1000: ', formatEther(priceFor1000) );
      const percentdivisor = BigInt(100n)
      
      priceFor1000 = BigInt(priceFor1000) + BigInt ( priceFor1000) / BigInt(percentdivisor)
      txBuy = await funToken.buy(parseEther('34612000'), '100000', {value:  priceFor1000 });
      txBuyReceipt = await txBuy.wait();

      console.log('buy with token finished: ' );

      const tokensToBuy = 5;
      const tokensToBuyWithFees = tokensToBuy + ( (1/100)* tokensToBuy);

      txBuy = await funToken.buyWithETH(parseEther(tokensToBuy.toString()), '10000', {value: parseEther(tokensToBuyWithFees.toString())});
      txBuyReceipt = await txBuy.wait();

      txBuy = await funToken.buyWithETH(parseEther(tokensToBuy.toString()), '10000', {value: parseEther(tokensToBuyWithFees.toString())});
      txBuyReceipt = await txBuy.wait();

      txBuy = await funToken.buyWithETH(parseEther(tokensToBuy.toString()), '10000', {value: parseEther(tokensToBuyWithFees.toString())});
      txBuyReceipt = await txBuy.wait();

      let liqSent = await funToken.liquiditySent();
      expect(liqSent).equal(false);

      txBuy = await funToken.buyWithETH(parseEther(tokensToBuy.toString()), '10000', {value: parseEther(tokensToBuyWithFees.toString())});
      txBuyReceipt = await txBuy.wait();

      txBuy = await funToken.buyWithETH(parseEther(tokensToBuy.toString()), '10000', {value: parseEther(tokensToBuyWithFees.toString())});
      txBuyReceipt = await txBuy.wait();

      

      let netBoughtTokens = formatEther( await funToken.netBoughtTokens());
      console.log('netBoughtTokens', netBoughtTokens)

      let ethPaid = await funToken.ethPaid();
      console.log('ethPaid', formatEther(ethPaid))

      let toPay =  BigInt(parseEther('30').toBigInt()) - BigInt(ethPaid);
      console.log('toPay', formatEther(toPay))

      txBuy = await funToken.buyWithETH(toPay, '10000', {value: toPay + (BigInt(1) * toPay/ BigInt(100) )});
      txBuyReceipt = await txBuy.wait();

      liqSent = await funToken.liquiditySent();
      expect(liqSent).equal(true);

    

     

      // // // console.log('txbuy: ', txBuyReceipt)

      // // console.log('Balance 3: ', tokenAddress, ', balabce: ', formatEther( await hre.ethers.provider.getBalance(tokenAddress)) );
      
      // // expect(txBuyReceipt.status).to.equal(1);
    });

    
  });

  
});
