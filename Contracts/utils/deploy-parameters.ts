export const PopCoinDeploymentParameters: {
    [index: number]: {
        initVirtualEthReserve: number,
        createTokenFee: number,
        transactionFeePercent_x_100?: number,
        deployLiquidityFee: number        
    };
} = {
    31337: {
        initVirtualEthReserve: 2.21, // 10 - MarketCap(in native currency) / 13.57
        createTokenFee: 0.001,
        transactionFeePercent_x_100: 100,
        deployLiquidityFee: 0.9 // 1.5
    },
    252: {//Fraxtal
        initVirtualEthReserve: 2.21, 
        createTokenFee: 0.001,
        transactionFeePercent_x_100: 100,
        deployLiquidityFee: 0.9 // 1.5
    },
    250: {// fantom
        initVirtualEthReserve: 8253, //  73667,
        createTokenFee: 2,
        transactionFeePercent_x_100: 50,
        deployLiquidityFee: 3300
    },
    4002: {//Fantom-testnet
        initVirtualEthReserve: 8253,
        createTokenFee: 0.001,
        transactionFeePercent_x_100: 50,
        deployLiquidityFee: 3300
    },
    44787: {//Celo-testnet
        initVirtualEthReserve: 8250,
        createTokenFee: 0.01,
        transactionFeePercent_x_100: 100,
        deployLiquidityFee: 3800
    },
    42220: {//Celo
        initVirtualEthReserve: 8250,
        createTokenFee: 2,
        transactionFeePercent_x_100: 100,
        deployLiquidityFee: 3800
    },
    1115: {//Core -testnet
        initVirtualEthReserve: 7000,
        createTokenFee: 0.01,
        transactionFeePercent_x_100: 100,
        deployLiquidityFee: 2200
    },

    1116: {//Core
        initVirtualEthReserve: 3500,
        createTokenFee: 1.25,
        transactionFeePercent_x_100: 100,
        deployLiquidityFee: 1500
    },

    656476: {//Open Campus Educhain -testnet
        initVirtualEthReserve: 60000,
        createTokenFee: 0.01,
        transactionFeePercent_x_100: 100,
        deployLiquidityFee: 2750
    },

    97: {//BSC -testnet
        initVirtualEthReserve: 9.51,
        createTokenFee: 0.005,
        transactionFeePercent_x_100: 100,
        deployLiquidityFee: 4.5
    },

    5611:{ // OP BNB test
        initVirtualEthReserve: 9.51,
        createTokenFee: 0.005,
        transactionFeePercent_x_100: 100,
        deployLiquidityFee: 4.5
    },

    696969:{ // Galadriel  test
        initVirtualEthReserve: 60000,
        createTokenFee: 0.005,
        transactionFeePercent_x_100: 100,
        deployLiquidityFee: 6
    },
    2810: { //Morph Holesky
        initVirtualEthReserve: 2.21,
        createTokenFee: 0.0005,
        transactionFeePercent_x_100: 100,
        deployLiquidityFee: 0.5
    },

    12227332: { // NEO X testnet
        initVirtualEthReserve: 1200,
        createTokenFee: 0.25,
        transactionFeePercent_x_100: 100,
        deployLiquidityFee: 500
    },

    47763: { // NEO X 
        initVirtualEthReserve: 1200,
        createTokenFee: 0.5,
        transactionFeePercent_x_100: 100,
        deployLiquidityFee: 500
    },

    1313161555: { // Aurora testnet
        initVirtualEthReserve: 2.21,
        createTokenFee: 0.001,
        transactionFeePercent_x_100: 100,
        deployLiquidityFee: 0.9
    },

    1313161554: { // Aurora 
        initVirtualEthReserve: 2.21,
        createTokenFee: 0.001,
        transactionFeePercent_x_100: 100,
        deployLiquidityFee: 0.9
    },

}