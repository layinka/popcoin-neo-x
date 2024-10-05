import { createConfig } from "@ponder/core";
import { http } from "viem";

import { PopCoinFactoryABI } from "./abis/PopCoinFactoryABI";
import { hardhat } from "viem/chains";

export default createConfig({
  database: {
    kind: "sqlite",
    directory: "./.ponder/sqlite-db",
  },
  networks: {
    fraxtalTestnet: {
      chainId: 2522,
      transport: http("https://rpc.testnet.frax.com"),
    },
    fraxtal: {
      chainId: 252,
      transport: http("https://rpc.frax.com"),
    },
    baseSepolia: {
      chainId: 84532,
      transport: http("https://sepolia.base.org"),
    },
    hardhat: {
      chainId: 31337,
      transport: http("http://127.0.0.1:8545"),
    },
  },
  contracts: {
    PopCoinFactoryV2: {
      address: "0xD62BfbF2050e8fEAD90e32558329D43A6efce4C8" as `0x${string}`,
      network: {
        // fraxtal: { startBlock: 6271421 },
        // fraxtalTestnet: { startBlock: 9666828 },
        // baseSepolia: {
        //   address: "0xFA598e9Bd1970E0cB42b1e23549A6d5436680b51",
        //   startBlock: 11972482,
        // },
        hardhat: {
          address: '0x8A791620dd6260079BF849Dc5567aDC3F2FdC318',
          startBlock: 9
        },
      },
      abi: PopCoinFactoryABI,
    },
  },
});
