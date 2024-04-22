import { config as dotenvConfig } from "dotenv";
import { ethers } from "ethers";
import { resolve } from "path";
import {
  ChainId,
  HardhatChainName,
  ChainSlug,
  ChainSlugToKey,
} from "../../src";

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

    case HardhatChainName.CDK_TESTNET:
    case ChainId.CDK_TESTNET:
      jsonRpcUrl = process.env.CDK_TESTNET_RPC as string;
      break;

    case HardhatChainName.SX_NETWORK_TESTNET:
    case ChainId.SX_NETWORK_TESTNET:
      jsonRpcUrl = process.env.SX_NETWORK_TESTNET_RPC as string;
      break;

    case HardhatChainName.SX_NETWORK:
    case ChainId.SX_NETWORK:
      jsonRpcUrl = process.env.SX_NETWORK_RPC as string;
      break;

    case HardhatChainName.MODE_TESTNET:
    case ChainId.MODE_TESTNET:
      jsonRpcUrl = process.env.MODE_TESTNET_RPC as string;
      break;

    case HardhatChainName.VICTION_TESTNET:
    case ChainId.VICTION_TESTNET:
      jsonRpcUrl = process.env.VICTION_TESTNET_RPC as string;
      break;

    case HardhatChainName.BASE:
    case ChainId.BASE:
      jsonRpcUrl = process.env.BASE_RPC as string;
      break;

    case HardhatChainName.MODE:
    case ChainId.MODE:
      jsonRpcUrl = process.env.MODE_RPC as string;
      break;

    case HardhatChainName.ANCIENT8_TESTNET:
    case ChainId.ANCIENT8_TESTNET:
      jsonRpcUrl = process.env.ANCIENT8_TESTNET_RPC as string;
      break;

    case HardhatChainName.ANCIENT8_TESTNET2:
    case ChainId.ANCIENT8_TESTNET2:
      jsonRpcUrl = process.env.ANCIENT8_TESTNET2_RPC as string;
      break;

    case HardhatChainName.HOOK_TESTNET:
    case ChainId.HOOK_TESTNET:
      jsonRpcUrl = process.env.HOOK_TESTNET_RPC as string;
      break;

    case HardhatChainName.HOOK:
    case ChainId.HOOK:
      jsonRpcUrl = process.env.HOOK_RPC as string;
      break;

    case HardhatChainName.PARALLEL:
    case ChainId.PARALLEL:
      jsonRpcUrl = process.env.PARALLEL_RPC as string;
      break;

    case HardhatChainName.MANTLE:
    case ChainId.MANTLE:
      jsonRpcUrl = process.env.MANTLE_RPC as string;
      break;

    case HardhatChainName.REYA_CRONOS:
    case ChainId.REYA_CRONOS:
      jsonRpcUrl = process.env.REYA_CRONOS_RPC as string;
      break;

    case HardhatChainName.REYA:
    case ChainId.REYA:
      jsonRpcUrl = process.env.REYA_RPC as string;
      break;

    case HardhatChainName.SYNDR_SEPOLIA_L3:
    case ChainId.SYNDR_SEPOLIA_L3:
      jsonRpcUrl = process.env.SYNDR_SEPOLIA_L3_RPC as string;
      break;

    case HardhatChainName.POLYNOMIAL_TESTNET:
    case ChainId.POLYNOMIAL_TESTNET:
      jsonRpcUrl = process.env.POLYNOMIAL_TESTNET_RPC as string;
      break;

    case HardhatChainName.HARDHAT:
    case ChainId.HARDHAT:
      jsonRpcUrl = "http://127.0.0.1:8545/";
      break;

    case HardhatChainName.OPTIMISM_SEPOLIA:
    case ChainId.OPTIMISM_SEPOLIA:
      jsonRpcUrl = process.env.OPTIMISM_SEPOLIA_RPC as string;
      break;

    case HardhatChainName.ARBITRUM_SEPOLIA:
    case ChainId.ARBITRUM_SEPOLIA:
      jsonRpcUrl = process.env.ARBITRUM_SEPOLIA_RPC as string;
      break;

    case HardhatChainName.KINTO:
    case ChainId.KINTO:
      jsonRpcUrl = process.env.KINTO_RPC as string;
      break;

    case HardhatChainName.KINTO_DEVNET:
    case ChainId.KINTO_DEVNET:
      jsonRpcUrl = process.env.KINTO_RPC_DEVNET as string;
      break;

    default:
      if (process.env.NEW_RPC) {
        jsonRpcUrl = process.env.NEW_RPC as string;
      } else throw new Error(`JSON RPC URL not found for ${chain}!!`);
  }

  return jsonRpcUrl;
}

const getProviderFromChainName = (hardhatChainName: HardhatChainName) => {
  const jsonRpcUrl = getJsonRpcUrl(hardhatChainName);
  return new ethers.providers.StaticJsonRpcProvider(jsonRpcUrl);
};

export const getProviderFromChainSlug = (chainSlug: ChainSlug) => {
  return getProviderFromChainName(ChainSlugToKey[chainSlug]);
};
