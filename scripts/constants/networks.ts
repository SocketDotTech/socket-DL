import { config as dotenvConfig } from "dotenv";
import { ethers } from "ethers";
import { resolve } from "path";
import { ChainSlug } from "../../src";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

const infuraApiKey: string | undefined = process.env.INFURA_API_KEY;

export const chainSlugs = {
  avalanche: 43114,
  bsc: 56,
  goerli: 5,
  hardhat: 31337,
  mainnet: 1,
  "bsc-testnet": 97,
  arbitrum: 42161,
  "arbitrum-goerli": 421613,
  optimism: 10,
  "optimism-goerli": 420,
  "polygon-mainnet": 137,
  "polygon-mumbai": 80001,
};

export const networkToChainSlug = {
  43114: "avalanche",
  56: "bsc",
  5: "goerli",
  31337: "hardhat",
  1: "mainnet",
  97: "bsc-testnet",
  42161: "arbitrum",
  421613: "arbitrum-goerli",
  10: "optimism",
  420: "optimism-goerli",
  137: "polygon-mainnet",
  80001: "polygon-mumbai",
};

export const chainSlugKeys: string[] = Object.values(networkToChainSlug);

export function getJsonRpcUrl(chain: keyof typeof chainSlugs): string {
  let jsonRpcUrl: string;
  switch (chain) {
    case "arbitrum":
      jsonRpcUrl = process.env.ARBITRUM_RPC as string;
      break;

    case "arbitrum-goerli":
      jsonRpcUrl = process.env.ARBITRUM_GOERLI_RPC as string;
      break;

    case "optimism":
      jsonRpcUrl = process.env.OPTIMISM_RPC as string;
      break;

    case "optimism-goerli":
      jsonRpcUrl = process.env.OPTIMISM_GOERLI_RPC as string;
      break;

    case "polygon-mainnet":
      jsonRpcUrl = process.env.POLYGON_RPC as string;
      break;

    case "polygon-mumbai":
      jsonRpcUrl = process.env.POLYGON_MUMBAI_RPC as string;
      break;

    case "avalanche":
      jsonRpcUrl = process.env.AVAX_RPC as string;
      break;

    case "bsc":
      jsonRpcUrl = process.env.BSC_RPC as string;
      break;

    case "bsc-testnet":
      jsonRpcUrl = process.env.BSC_TESTNET_RPC as string;
      break;

    case "mainnet":
      jsonRpcUrl = process.env.ETHEREUM_RPC as string;
      break;

    case "goerli":
      jsonRpcUrl = process.env.GOERLI_RPC as string;
      break;

    default:
      jsonRpcUrl = "https://" + chain + ".infura.io/v3/" + infuraApiKey;
  }

  return jsonRpcUrl;
}

export const getProviderFromChainName = (
  chainSlug: keyof typeof chainSlugs
) => {
  const jsonRpcUrl = getJsonRpcUrl(chainSlug);
  return new ethers.providers.JsonRpcProvider(jsonRpcUrl);
};
