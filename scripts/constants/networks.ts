import { config as dotenvConfig } from "dotenv";
import { ethers } from "ethers";
import { resolve } from "path";
import { ChainId, ChainKey, ChainSlug, ChainSlugToKey } from "../../src";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

export const chainSlugKeys: string[] = Object.values(ChainSlugToKey);

export function getJsonRpcUrl(chain: ChainKey | ChainId): string {
  let jsonRpcUrl: string;
  switch (chain) {
    case ChainKey.ARBITRUM:
    case ChainId.ARBITRUM:
      jsonRpcUrl = process.env.ARBITRUM_RPC as string;
      break;

    case ChainKey.ARBITRUM_GOERLI:
    case ChainId.ARBITRUM_GOERLI:
      jsonRpcUrl = process.env.ARB_GOERLI_RPC as string;
      break;

    case ChainKey.OPTIMISM:
    case ChainId.OPTIMISM:
      jsonRpcUrl = process.env.OPTIMISM_RPC as string;
      break;

    case ChainKey.OPTIMISM_GOERLI:
    case ChainId.OPTIMISM_GOERLI:
      jsonRpcUrl = process.env.OPTIMISM_GOERLI_RPC as string;
      break;

    case ChainKey.POLYGON_MAINNET:
    case ChainId.POLYGON_MAINNET:
      jsonRpcUrl = process.env.POLYGON_RPC as string;
      break;

    case ChainKey.POLYGON_MUMBAI:
    case ChainId.POLYGON_MUMBAI:
      jsonRpcUrl = process.env.POLYGON_MUMBAI_RPC as string;
      break;

    case ChainKey.AVALANCHE:
    case ChainId.AVALANCHE:
      jsonRpcUrl = process.env.AVAX_RPC as string;
      break;

    case ChainKey.BSC:
    case ChainId.BSC:
      jsonRpcUrl = process.env.BSC_RPC as string;
      break;

    case ChainKey.BSC_TESTNET:
    case ChainId.BSC_TESTNET:
      jsonRpcUrl = process.env.BSC_TESTNET_RPC as string;
      break;

    case ChainKey.MAINNET:
    case ChainId.MAINNET:
      jsonRpcUrl = process.env.ETHEREUM_RPC as string;
      break;

    case ChainKey.GOERLI:
    case ChainId.GOERLI:
      jsonRpcUrl = process.env.GOERLI_RPC as string;
      break;

    case ChainKey.SEPOLIA:
    case ChainId.SEPOLIA:
      jsonRpcUrl = process.env.SEPOLIA_RPC as string;
      break;

    case ChainKey.AEVO_TESTNET:
    case ChainId.AEVO_TESTNET:
      jsonRpcUrl = process.env.AEVO_TESTNET_RPC as string;
      break;

    case ChainKey.AEVO:
    case ChainId.AEVO:
      jsonRpcUrl = process.env.AEVO_RPC as string;
      break;

    case ChainKey.LYRA_TESTNET:
    case ChainId.LYRA_TESTNET:
      jsonRpcUrl = process.env.LYRA_TESTNET_RPC as string;
      break;

    case ChainKey.LYRA:
    case ChainId.LYRA:
      jsonRpcUrl = process.env.LYRA_RPC as string;
      break;

    case ChainKey.XAI_TESTNET:
    case ChainId.XAI_TESTNET:
      jsonRpcUrl = process.env.XAI_TESTNET_RPC as string;
      break;

    case ChainKey.HARDHAT:
    case ChainId.HARDHAT:
      jsonRpcUrl = "http://127.0.0.1:8545/";
      break;

    default:
      throw new Error("JSON RPC URL not found!!");
  }

  return jsonRpcUrl;
}

const getProviderFromChainName = (chainKey: ChainKey) => {
  const jsonRpcUrl = getJsonRpcUrl(chainKey);
  return new ethers.providers.StaticJsonRpcProvider(jsonRpcUrl);
};

export const getProviderFromChainSlug = (chainSlug: ChainSlug) => {
  return getProviderFromChainName(ChainSlugToKey[chainSlug]);
};
