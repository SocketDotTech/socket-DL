import { config as dotenvConfig } from "dotenv";
import { resolve } from "path";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });

const infuraApiKey: string | undefined = process.env.INFURA_API_KEY;

export const chainIds = {
  avalanche: 43114,
  bsc: 56,
  goerli: 5,
  hardhat: 31337,
  mainnet: 1,
  "bsc-testnet": 97,
  "arbitrum": 42161,
  "arbitrum-goerli": 421613,
  "optimism": 10,
  "optimism-goerli": 420,
  "polygon-mainnet": 137,
  "polygon-mumbai": 80001,
};

export const networkToChainId = {
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

export function getJsonRpcUrl(chain: keyof typeof chainIds): string {
  let jsonRpcUrl: string;
  switch (chain) {
    case "arbitrum-goerli":
      jsonRpcUrl = "https://goerli-rollup.arbitrum.io/rpc";
      break;
    case "optimism-goerli":
      jsonRpcUrl = "https://goerli.optimism.io";
      break;
    case "polygon-mumbai":
      jsonRpcUrl = "https://matic-mumbai.chainstacklabs.com";
      break;
    case "avalanche":
      jsonRpcUrl = "https://api.avax.network/ext/bc/C/rpc";
      break;
    case "bsc":
      jsonRpcUrl = "https://bsc-dataseed1.binance.org";
      break;
    case "bsc-testnet":
      jsonRpcUrl = "https://data-seed-prebsc-1-s1.binance.org:8545";
      break;
    case "optimism":
      jsonRpcUrl = "https://mainnet.optimism.io";
      break;
    case "arbitrum":
      jsonRpcUrl = "https://arb1.arbitrum.io/rpc ";
      break;
    case "goerli":
      jsonRpcUrl = process.env.GOERLI_RPC_URL;
      break;
    default:
      jsonRpcUrl = "https://" + chain + ".infura.io/v3/" + infuraApiKey;
  }

  return jsonRpcUrl;
}
