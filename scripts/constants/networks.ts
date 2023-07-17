import { config as dotenvConfig } from "dotenv";
import { ethers } from "ethers";
import { resolve } from "path";
import { ChainKey, ChainSlug, ChainSlugToKey } from "../../src";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

export const chainSlugKeys: string[] = Object.values(ChainSlugToKey);

export function getJsonRpcUrl(chain: ChainKey): string {
  let jsonRpcUrl: string;
  switch (chain) {
    case ChainKey.ARBITRUM:
      jsonRpcUrl = process.env.ARBITRUM_RPC as string;
      break;

    case ChainKey.ARBITRUM_GOERLI:
      jsonRpcUrl = process.env.ARB_GOERLI_RPC as string;
      break;

    case ChainKey.OPTIMISM:
      jsonRpcUrl = process.env.OPTIMISM_RPC as string;
      break;

    case ChainKey.OPTIMISM_GOERLI:
      jsonRpcUrl = process.env.OPTIMISM_GOERLI_RPC as string;
      break;

    case ChainKey.POLYGON_MAINNET:
      jsonRpcUrl = process.env.POLYGON_RPC as string;
      break;

    case ChainKey.POLYGON_MUMBAI:
      jsonRpcUrl = process.env.POLYGON_MUMBAI_RPC as string;
      break;

    case ChainKey.AVALANCHE:
      jsonRpcUrl = process.env.AVAX_RPC as string;
      break;

    case ChainKey.BSC:
      jsonRpcUrl = process.env.BSC_RPC as string;
      break;

    case ChainKey.BSC_TESTNET:
      jsonRpcUrl = process.env.BSC_TESTNET_RPC as string;
      break;

    case ChainKey.MAINNET:
      jsonRpcUrl = process.env.ETHEREUM_RPC as string;
      break;

    case ChainKey.GOERLI:
      jsonRpcUrl = process.env.GOERLI_RPC as string;
      break;

    case ChainKey.SEPOLIA:
      jsonRpcUrl = process.env.SEPOLIA_RPC as string;
      break;

    case ChainKey.AEVO_TESTNET:
      jsonRpcUrl = process.env.AEVO_TESTNET_RPC as string;
      break;

    case ChainKey.HARDHAT:
      jsonRpcUrl = "http://127.0.0.1:8545/";
      break;

    default:
      throw new Error("JSON RPC URL not found!!");
  }

  return jsonRpcUrl;
}

export const getProviderFromChainName = (chainKey: ChainKey) => {
  const jsonRpcUrl = getJsonRpcUrl(chainKey);
  return new ethers.providers.StaticJsonRpcProvider(jsonRpcUrl);
};

export const getProviderFromChainSlug = (chainSlug: ChainSlug) => {
  return getProviderFromChainName(ChainSlugToKey[chainSlug]);
};
