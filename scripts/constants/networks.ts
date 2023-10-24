import { config as dotenvConfig } from "dotenv";
import { ethers } from "ethers";
import { resolve } from "path";
import {
  ChainId,
  HardhatChainName,
  ChainSlug,
  ChainSlugToKey,
} from "../../src";
import chainConfig from "../../chainConfig.json";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

export function getJsonRpcUrl(chain: HardhatChainName | ChainId): string {
  let jsonRpcUrl: string;
  switch (chain) {
    case HardhatChainName.ARBITRUM:
    case ChainId.ARBITRUM:
      jsonRpcUrl = process.env.ARBITRUM_RPC as string;
      break;

    case HardhatChainName.ARBITRUM_GOERLI:
    case ChainId.ARBITRUM_GOERLI:
      jsonRpcUrl = process.env.ARB_GOERLI_RPC as string;
      break;

    case HardhatChainName.OPTIMISM:
    case ChainId.OPTIMISM:
      jsonRpcUrl = process.env.OPTIMISM_RPC as string;
      break;

    case HardhatChainName.OPTIMISM_GOERLI:
    case ChainId.OPTIMISM_GOERLI:
      jsonRpcUrl = process.env.OPTIMISM_GOERLI_RPC as string;
      break;

    case HardhatChainName.POLYGON_MAINNET:
    case ChainId.POLYGON_MAINNET:
      jsonRpcUrl = process.env.POLYGON_RPC as string;
      break;

    case HardhatChainName.POLYGON_MUMBAI:
    case ChainId.POLYGON_MUMBAI:
      jsonRpcUrl = process.env.POLYGON_MUMBAI_RPC as string;
      break;

    case HardhatChainName.AVALANCHE:
    case ChainId.AVALANCHE:
      jsonRpcUrl = process.env.AVAX_RPC as string;
      break;

    case HardhatChainName.BSC:
    case ChainId.BSC:
      jsonRpcUrl = process.env.BSC_RPC as string;
      break;

    case HardhatChainName.BSC_TESTNET:
    case ChainId.BSC_TESTNET:
      jsonRpcUrl = process.env.BSC_TESTNET_RPC as string;
      break;

    case HardhatChainName.MAINNET:
    case ChainId.MAINNET:
      jsonRpcUrl = process.env.ETHEREUM_RPC as string;
      break;

    case HardhatChainName.GOERLI:
    case ChainId.GOERLI:
      jsonRpcUrl = process.env.GOERLI_RPC as string;
      break;

    case HardhatChainName.SEPOLIA:
    case ChainId.SEPOLIA:
      jsonRpcUrl = process.env.SEPOLIA_RPC as string;
      break;

    case HardhatChainName.AEVO_TESTNET:
    case ChainId.AEVO_TESTNET:
      jsonRpcUrl = process.env.AEVO_TESTNET_RPC as string;
      break;

    case HardhatChainName.AEVO:
    case ChainId.AEVO:
      jsonRpcUrl = process.env.AEVO_RPC as string;
      break;

    case HardhatChainName.LYRA_TESTNET:
    case ChainId.LYRA_TESTNET:
      jsonRpcUrl = process.env.LYRA_TESTNET_RPC as string;
      break;

    case HardhatChainName.LYRA:
    case ChainId.LYRA:
      jsonRpcUrl = process.env.LYRA_RPC as string;
      break;

    case HardhatChainName.XAI_TESTNET:
    case ChainId.XAI_TESTNET:
      jsonRpcUrl = process.env.XAI_TESTNET_RPC as string;
      break;

    case HardhatChainName.HARDHAT:
    case ChainId.HARDHAT:
      jsonRpcUrl = "http://127.0.0.1:8545/";
      break;

    default:
      if (chainConfig[chain] && chainConfig[chain].rpc) {
        jsonRpcUrl = chainConfig[chain].rpc;
      } else throw new Error("JSON RPC URL not found!!");
  }

  return jsonRpcUrl;
}

const getProviderFromChainName = (hardhatChainName: HardhatChainName) => {
  const jsonRpcUrl = getJsonRpcUrl(hardhatChainName);
  return new ethers.providers.StaticJsonRpcProvider(jsonRpcUrl);
};

export const getProviderFromChainSlug = (chainSlug: ChainSlug) => {
  return getProviderFromChainName(ChainSlugToKey(chainSlug));
};
