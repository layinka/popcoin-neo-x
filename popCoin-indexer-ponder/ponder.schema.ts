import { createSchema } from "@ponder/core";

export default createSchema((p) => ({
  Token: p.createTable(
    {
      id: p.string(),
      chainId: p.int(),
      name: p.string(),
      symbol: p.string(),
      logoUrl: p.string(),
      bannerUrl: p.string(),
      address: p.string(),
      creator: p.string(),
      timestamp: p.bigint(),
      isMigrated: p.boolean(),
      description: p.string(),
      trades: p.many("Trade.tokenId"),
      prices: p.many("Price.tokenId"),
      marketCap: p.bigint().optional(),
      lpAddress: p.string().optional(),
      twitter: p.string().optional(),
      website: p.string().optional(),
      telegram: p.string().optional(),
      routerAddress: p.string(),
    },
    { creatorIndex: p.index("creator") },
  ),
  TradeType: p.createEnum(["BUY", "SELL"]),
  Trade: p.createTable({
    id: p.string(),
    fee: p.bigint(),
    chainId: p.int(),
    trader: p.string(),
    amountPaid: p.bigint(),
    timestamp: p.bigint(),
    tokensTraded: p.bigint(),
    token: p.one("tokenId"),
    tradeType: p.enum("TradeType"),
    tokenId: p.string().references("Token.id"),
  }),
  Price: p.createTable({
    id: p.int(), // Unix timestamp of the start of the hour.
    low: p.bigint(),
    open: p.bigint(),
    chainId: p.int(),
    high: p.bigint(),
    close: p.bigint(),
    count: p.bigint(),
    average: p.bigint(),
    token: p.one("tokenId"),
    tokenId: p.string().references("Token.id"),
  }),
}));