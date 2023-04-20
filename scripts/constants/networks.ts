import { config as dotenvConfig } from "dotenv";
import { ethers } from "ethers";
import { resolve } from "path";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

const infuraApiKey: string | undefined = process.env.INFURA_API_KEY;

export enum ChainKey {
  ARBITRUM = "arbitrum",
  ARBITRUM_GOERLI = "arbitrum-goerli",
  OPTIMISM = "optimism",
  OPTIMISM_GOERLI = "optimism-goerli",
  AVALANCHE = "avalanche",
  AVALANCHE_TESTNET = "avalanche-testnet",
  BSC = "bsc",
  BSC_TESTNET = "bsc-testnet",
  MAINNET = "mainnet",
  GOERLI = "goerli",
  POLYGON_MAINNET = "polygon-mainnet",
  POLYGON_MUMBAI = "polygon-mumbai",
  HARDHAT = "hardhat",
}

export const chainSlugs = {
  [ChainKey.ARBITRUM]: 42161,
  [ChainKey.ARBITRUM_GOERLI]: 421613,
  [ChainKey.OPTIMISM]: 10,
  [ChainKey.OPTIMISM_GOERLI]: 420,
  [ChainKey.AVALANCHE]: 43114,
  [ChainKey.BSC]: 56,
  [ChainKey.BSC_TESTNET]: 97,
  [ChainKey.MAINNET]: 1,
  [ChainKey.GOERLI]: 5,
  [ChainKey.POLYGON_MAINNET]: 137,
  [ChainKey.POLYGON_MUMBAI]: 80001,
  [ChainKey.HARDHAT]: 31337,
};

export const gasPrice: {
  [chainKEY in ChainKey]?: number | "auto" | undefined;
} = {
  [ChainKey.ARBITRUM]: "auto",
  [ChainKey.ARBITRUM_GOERLI]: "auto",
  [ChainKey.OPTIMISM]: "auto",
  [ChainKey.OPTIMISM_GOERLI]: 50000000,
  [ChainKey.AVALANCHE]: "auto",
  [ChainKey.BSC]: "auto",
  [ChainKey.BSC_TESTNET]: "auto",
  [ChainKey.MAINNET]: "auto",
  [ChainKey.GOERLI]: "auto",
  [ChainKey.POLYGON_MAINNET]: "auto",
  [ChainKey.POLYGON_MUMBAI]: "auto",
  [ChainKey.HARDHAT]: 31337,
};

export const networkToChainSlug = {
  43114: ChainKey.AVALANCHE,
  56: ChainKey.BSC,
  5: ChainKey.GOERLI,
  31337: ChainKey.HARDHAT,
  1: ChainKey.MAINNET,
  97: ChainKey.BSC_TESTNET,
  42161: ChainKey.ARBITRUM,
  421613: ChainKey.ARBITRUM_GOERLI,
  10: ChainKey.OPTIMISM,
  420: ChainKey.OPTIMISM_GOERLI,
  137: ChainKey.POLYGON_MAINNET,
  80001: ChainKey.POLYGON_MUMBAI,
};

export const chainSlugKeys: string[] = Object.values(networkToChainSlug);

export function getJsonRpcUrl(chain: ChainKey): string[] {
  let jsonRpcUrl: string[];
  switch (chain) {
    case ChainKey.ARBITRUM:
      jsonRpcUrl = [
        process.env.ARBITRUM_RPC as string,
        "https://arb1.arbitrum.io/rpc",
      ];
      break;

    case ChainKey.ARBITRUM_GOERLI:
      jsonRpcUrl = [
        process.env.ARB_GOERLI_RPC as string,
        "https://goerli-rollup.arbitrum.io/rpc",
        "https://arb-goerli.g.alchemy.com/v2/demo",
      ];
      break;

    case ChainKey.OPTIMISM:
      jsonRpcUrl = [
        process.env.OPTIMISM_RPC as string,
        "https://mainnet.optimism.io",
      ];
      break;

    case ChainKey.OPTIMISM_GOERLI:
      jsonRpcUrl = [
        process.env.OPTIMISM_GOERLI_RPC as string,
        "https://goerli.optimism.io",
        "https://opt-goerli.g.alchemy.com/v2/demo",
      ];
      break;

    case ChainKey.POLYGON_MAINNET:
      jsonRpcUrl = [
        process.env.POLYGON_RPC as string,
        "https://polygon-rpc.com/",
      ];
      break;

    case ChainKey.POLYGON_MUMBAI:
      jsonRpcUrl = [
        process.env.POLYGON_MUMBAI_RPC as string,
        "https://rpc-mumbai.maticvigil.com/",
      ];
      break;

    case ChainKey.AVALANCHE:
      jsonRpcUrl = [process.env.AVAX_RPC as string];
      break;

    case ChainKey.BSC:
      jsonRpcUrl = [
        process.env.BSC_RPC as string,
        "https://bsc-dataseed1.binance.org/",
      ];
      break;

    case ChainKey.BSC_TESTNET:
      jsonRpcUrl = [
        process.env.BSC_TESTNET_RPC as string,
        "https://data-seed-prebsc-1-s1.binance.org:8545/",
      ];
      break;

    case ChainKey.MAINNET:
      jsonRpcUrl = [process.env.ETHEREUM_RPC as string];
      break;

    case ChainKey.GOERLI:
      jsonRpcUrl = [process.env.GOERLI_RPC as string];
      break;

    default:
      jsonRpcUrl = ["https://" + chain + ".infura.io/v3/" + infuraApiKey];
  }

  return jsonRpcUrl;
}

export const getProviderFromChainName = (chainSlug: ChainKey) => {
  const jsonRpcUrl = getJsonRpcUrl(chainSlug);
  return new ethers.providers.JsonRpcProvider(jsonRpcUrl[0]);
};
