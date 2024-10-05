# PopCoin Contracts

## Crypto Meme Coin Factory

## INSTALL

```bash
npm install
```

## TEST

### hardhat
```shell
npx hardhat test
REPORT_GAS=true npx hardhat test
```



## Deploy with Hardhat-Deploy

### Deploy

`npx hardhat deploy <network> [args...]`





## Deploy with Hardhat Ignition

### Deploy

`npx hardhat ignition deploy ./ignition/modules/Lock.ts <network> [args...]`

### Deploy with Create2
`npx hardhat ignition deploy ignition/modules/[module].ts --network [network] --strategy create2`

`npx hardhat ignition deploy ignition/modules/[module].ts --network [network] --strategy create2 --deployment-id second-deploy`

`npx hardhat ignition deploy ignition/modules/Lock.ts --network localhost --strategy create2`




