import { ChainSlug, MainnetIds } from "../../src";
import dotenv from "dotenv";
dotenv.config();

export function checkEnvVar(envVar: string) {
  let value = process.env[envVar];
  if (!value) {
    throw new Error(`Missing environment variable ${envVar}`);
  }
  return value;
}

export const prodVersion = "prod-1.0.4";
export const devVersion = "dev-1.0.0";

export const rpcs = {
  [ChainSlug.AEVO]: checkEnvVar("AEVO_RPC"),
  [ChainSlug.ARBITRUM]: checkEnvVar("ARBITRUM_RPC"),
  [ChainSlug.LYRA]: checkEnvVar("LYRA_RPC"),
  [ChainSlug.OPTIMISM]: checkEnvVar("OPTIMISM_RPC"),
  [ChainSlug.BSC]: checkEnvVar("BSC_RPC"),
  [ChainSlug.POLYGON_MAINNET]: checkEnvVar("POLYGON_RPC"),
  [ChainSlug.MAINNET]: checkEnvVar("ETHEREUM_RPC"),
  [ChainSlug.PARALLEL]: checkEnvVar("PARALLEL_RPC"),
  [ChainSlug.HOOK]: checkEnvVar("HOOK_RPC"),
  [ChainSlug.MANTLE]: checkEnvVar("MANTLE_RPC"),
  [ChainSlug.REYA]: checkEnvVar("REYA_RPC"),
  [ChainSlug.ARBITRUM_SEPOLIA]: checkEnvVar("ARBITRUM_SEPOLIA_RPC"),
  [ChainSlug.OPTIMISM_SEPOLIA]: checkEnvVar("OPTIMISM_SEPOLIA_RPC"),
  [ChainSlug.SEPOLIA]: checkEnvVar("SEPOLIA_RPC"),
  [ChainSlug.POLYGON_MUMBAI]: checkEnvVar("POLYGON_MUMBAI_RPC"),
  [ChainSlug.ARBITRUM_GOERLI]: checkEnvVar("ARB_GOERLI_RPC"),
  [ChainSlug.AEVO_TESTNET]: checkEnvVar("AEVO_TESTNET_RPC"),
  [ChainSlug.LYRA_TESTNET]: checkEnvVar("LYRA_TESTNET_RPC"),
  [ChainSlug.OPTIMISM_GOERLI]: checkEnvVar("OPTIMISM_GOERLI_RPC"),
  [ChainSlug.BSC_TESTNET]: checkEnvVar("BSC_TESTNET_RPC"),
  [ChainSlug.GOERLI]: checkEnvVar("GOERLI_RPC"),
  [ChainSlug.XAI_TESTNET]: checkEnvVar("XAI_TESTNET_RPC"),
  [ChainSlug.SX_NETWORK_TESTNET]: checkEnvVar("SX_NETWORK_TESTNET_RPC"),
  [ChainSlug.SX_NETWORK]: checkEnvVar("SX_NETWORK_RPC"),
  [ChainSlug.MODE_TESTNET]: checkEnvVar("MODE_TESTNET_RPC"),
  [ChainSlug.VICTION_TESTNET]: checkEnvVar("VICTION_TESTNET_RPC"),
  [ChainSlug.BASE]: checkEnvVar("BASE_RPC"),
  [ChainSlug.MODE]: checkEnvVar("MODE_RPC"),
  [ChainSlug.ANCIENT8_TESTNET]: checkEnvVar("ANCIENT8_TESTNET_RPC"),
  [ChainSlug.ANCIENT8_TESTNET2]: checkEnvVar("ANCIENT8_TESTNET2_RPC"),
  [ChainSlug.HOOK_TESTNET]: checkEnvVar("HOOK_TESTNET_RPC"),
  [ChainSlug.REYA_CRONOS]: checkEnvVar("REYA_CRONOS_RPC"),
  [ChainSlug.SYNDR_SEPOLIA_L3]: checkEnvVar("SYNDR_SEPOLIA_L3_RPC"),
  [ChainSlug.POLYNOMIAL_TESTNET]: checkEnvVar("POLYNOMIAL_TESTNET_RPC"),
  [ChainSlug.CDK_TESTNET]: checkEnvVar("CDK_TESTNET_RPC"),
};

export const confirmations = {
  [ChainSlug.AEVO]: 2,
  [ChainSlug.ARBITRUM]: 1,
  [ChainSlug.LYRA]: 2,
  [ChainSlug.OPTIMISM]: 15,
  [ChainSlug.BSC]: 1,
  [ChainSlug.POLYGON_MAINNET]: 256,
  [ChainSlug.MAINNET]: 18,
  [ChainSlug.BASE]: 1,
  [ChainSlug.MODE]: 2,
  [ChainSlug.ARBITRUM_GOERLI]: 1,
  [ChainSlug.AEVO_TESTNET]: 1,
  [ChainSlug.LYRA_TESTNET]: 1,
  [ChainSlug.OPTIMISM_GOERLI]: 1,
  [ChainSlug.BSC_TESTNET]: 1,
  [ChainSlug.GOERLI]: 1,
  [ChainSlug.XAI_TESTNET]: 1,
  [ChainSlug.SX_NETWORK_TESTNET]: 1,
  [ChainSlug.SX_NETWORK]: 1,
  [ChainSlug.MODE_TESTNET]: 1,
  [ChainSlug.VICTION_TESTNET]: 1,
  [ChainSlug.CDK_TESTNET]: 1,
  [ChainSlug.ARBITRUM_SEPOLIA]: 1,
  [ChainSlug.OPTIMISM_SEPOLIA]: 1,
  [ChainSlug.SEPOLIA]: 1,
  [ChainSlug.POLYGON_MUMBAI]: 1,
  [ChainSlug.ANCIENT8_TESTNET]: 1,
  [ChainSlug.ANCIENT8_TESTNET2]: 1,
  [ChainSlug.HOOK_TESTNET]: 1,
  [ChainSlug.HOOK]: 1,
  [ChainSlug.PARALLEL]: 1,
  [ChainSlug.MANTLE]: 1,
  [ChainSlug.REYA_CRONOS]: 1,
  [ChainSlug.REYA]: 0,
  [ChainSlug.SYNDR_SEPOLIA_L3]: 1,
  [ChainSlug.POLYNOMIAL_TESTNET]: 1,
};

export const prodBatcherSupportedChainSlugs = [
  ChainSlug.AEVO,
  ChainSlug.ARBITRUM,
  ChainSlug.OPTIMISM,
  ChainSlug.BSC,
  ChainSlug.POLYGON_MAINNET,
  ChainSlug.LYRA,
  ChainSlug.MAINNET,
  ChainSlug.MANTLE,
  ChainSlug.HOOK,
  ChainSlug.REYA,
  ChainSlug.SX_NETWORK,
  ChainSlug.AEVO_TESTNET,
  ChainSlug.SEPOLIA,
  ChainSlug.POLYGON_MUMBAI,
  ChainSlug.LYRA_TESTNET,
  ChainSlug.SX_NETWORK_TESTNET,
  ChainSlug.ARBITRUM_SEPOLIA,
  ChainSlug.OPTIMISM_SEPOLIA,
  ChainSlug.MODE_TESTNET,
  ChainSlug.BASE,
  ChainSlug.MODE,
  ChainSlug.ANCIENT8_TESTNET2,
  ChainSlug.HOOK_TESTNET,
  ChainSlug.REYA_CRONOS,
  ChainSlug.SYNDR_SEPOLIA_L3,
  ChainSlug.POLYNOMIAL_TESTNET,
];

export const prodFeesUpdaterSupportedChainSlugs = (): ChainSlug[] => {
  const feesUpdaterSupportedChainSlugs = [];
  MainnetIds.every((m) => {
    if (prodBatcherSupportedChainSlugs.includes(m))
      feesUpdaterSupportedChainSlugs.push(m);
  });

  return [...feesUpdaterSupportedChainSlugs, ChainSlug.POLYNOMIAL_TESTNET];
};
