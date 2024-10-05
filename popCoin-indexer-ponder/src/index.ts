import { ponder } from "@/generated";
import { sha256 } from "viem";

ponder.on("PopCoinFactoryV2:TokenCreated", async ({ event, context }) => {
  const { Token } = context.db;

  await Token.create({
    id: sha256(`${event.args.tokenAddress}:${context.network.chainId}`),
    data: {
      isMigrated: false,
      name: event.args.name,
      symbol: event.args.symbol,
      logoUrl: event.args.logo,
      bannerUrl: event.args.logo,
      address: event.args.tokenAddress,
      creator: event.args.creator,
      website: event.args.website,
      timestamp: event.block.timestamp,
      chainId: context.network.chainId,
      description: event.args.description,
      twitter: event.args.twitter,
      telegram: event.args.telegram,
      routerAddress: event.args.routerAddress
    },
  });
});

ponder.on("PopCoinFactoryV2:PriceUpdated", async ({ event, context }) => {
  const secondsInHour = 3600n;
  const { Token, Price } = context.db;

  const hourId = Math.floor(
    Number((event.block.timestamp / secondsInHour) * secondsInHour),
  );

  await Price.upsert({
    id: hourId,
    create: {
      count: 1n,
      low: event.args.price,
      high: event.args.price,
      open: event.args.price,
      close: event.args.price,
      average: event.args.price,
      chainId: context.network.chainId,
      tokenId: sha256(`${event.args.token}:${context.network.chainId}`),
    },
    update: ({ current }) => ({
      close: event.args.price,
      low: current.low > event.args.price ? event.args.price : current.low,
      high: current.high < event.args.price ? event.args.price : current.high,
      average:
        (current.average * current.count + event.args.price) / current.count +
        1n,
      count: current.count + 1n,
    }),
  });

  await Token.update({
    data: { marketCap: event.args.mcapEth },
    id: sha256(`${event.args.token}:${context.network.chainId}`),
  });
});

ponder.on("PopCoinFactoryV2:TokenTraded", async ({ event, context }) => {
  const { Trade } = context.db;

  await Trade.create({
    id: sha256(
      `${event.transaction.hash}:${event.log.logIndex}:${context.network.chainId}:${event.block.timestamp}`,
    ),
    data: {
      fee: event.args.fee,
      trader: event.args.trader,
      amountPaid: event.args.amountPaid,
      tokensTraded: event.args.tokensTraded,
      timestamp: event.args.timestamp,
      chainId: context.network.chainId,
      tradeType: event.args.isBuy ? "BUY" : "SELL",
      tokenId: sha256(`${event.args.tokenAddress}:${context.network.chainId}`),
    },
  });
});

ponder.on("PopCoinFactoryV2:LiquidityMigrated", async ({ event, context }) => {
  const { Token } = context.db;

  await Token.update({
    id: sha256(`${event.args.tokenAddress}:${context.network.chainId}`),
    data: { lpAddress: event.args.pair, isMigrated: true },
  });
});
