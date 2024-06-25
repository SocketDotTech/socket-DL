import dotenv from "dotenv";
import { batcherSupportedChainSlugs } from "./";
import { ChainSlug, MainnetIds } from "../../../src";
dotenv.config();

export function checkEnvVar(envVar: string) {
  let value = process.env[envVar];
  if (!value) {
    throw new Error(`Missing environment variable ${envVar}`);
  }
  return value;
}

export const prodFeesUpdaterSupportedChainSlugs = (): ChainSlug[] => {
  const feesUpdaterSupportedChainSlugs = [];
  MainnetIds.forEach((m) => {
    if (batcherSupportedChainSlugs.includes(m)) {
      feesUpdaterSupportedChainSlugs.push(m);
    }
  });

  return [
    ...feesUpdaterSupportedChainSlugs,
    // ChainSlug.POLYNOMIAL_TESTNET,
    // ChainSlug.KINTO_DEVNET,
    // ChainSlug.ARBITRUM_SEPOLIA,
  ];
};

export const rpcs = {
  [ChainSlug.AEVO]: checkEnvVar("AEVO_RPC"),
  [ChainSlug.ARBITRUM]: checkEnvVar("ARBITRUM_RPC"),
  [ChainSlug.LYRA]: checkEnvVar("LYRA_RPC"),
  [ChainSlug.OPTIMISM]: checkEnvVar("OPTIMISM_RPC"),
  [ChainSlug.BSC]: checkEnvVar("BSC_RPC"),
  [ChainSlug.POLYGON_MAINNET]: checkEnvVar("POLYGON_MAINNET_RPC"),
  [ChainSlug.MAINNET]: checkEnvVar("MAINNET_RPC"),
  [ChainSlug.PARALLEL]: checkEnvVar("PARALLEL_RPC"),
  [ChainSlug.HOOK]: checkEnvVar("HOOK_RPC"),
  [ChainSlug.MANTLE]: checkEnvVar("MANTLE_RPC"),
  [ChainSlug.REYA]: checkEnvVar("REYA_RPC"),
  [ChainSlug.ARBITRUM_SEPOLIA]: checkEnvVar("ARBITRUM_SEPOLIA_RPC"),
  [ChainSlug.OPTIMISM_SEPOLIA]: checkEnvVar("OPTIMISM_SEPOLIA_RPC"),
  [ChainSlug.SEPOLIA]: checkEnvVar("SEPOLIA_RPC"),
  [ChainSlug.ARBITRUM_GOERLI]: checkEnvVar("ARBITRUM_GOERLI_RPC"),
  [ChainSlug.AEVO_TESTNET]: checkEnvVar("AEVO_TESTNET_RPC"),
  [ChainSlug.LYRA_TESTNET]: checkEnvVar("LYRA_TESTNET_RPC"),
  [ChainSlug.OPTIMISM_GOERLI]: checkEnvVar("OPTIMISM_GOERLI_RPC"),
  [ChainSlug.GOERLI]: checkEnvVar("GOERLI_RPC"),
  [ChainSlug.XAI_TESTNET]: checkEnvVar("XAI_TESTNET_RPC"),
  [ChainSlug.SX_NETWORK_TESTNET]: checkEnvVar("SXN_TESTNET_RPC"),
  [ChainSlug.SX_NETWORK]: checkEnvVar("SXN_RPC"),
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
  [ChainSlug.BOB]: checkEnvVar("BOB_RPC"),
  [ChainSlug.KINTO]: checkEnvVar("KINTO_RPC"),
  [ChainSlug.KINTO_DEVNET]: checkEnvVar("KINTO_DEVNET_RPC"),
  [ChainSlug.CDK_TESTNET]: checkEnvVar("CDK_TESTNET_RPC"),
  [ChainSlug.SIPHER_FUNKI_TESTNET]: checkEnvVar("SIPHER_FUNKI_TESTNET_RPC"),
  [ChainSlug.WINR]: checkEnvVar("WINR_RPC"),
  [ChainSlug.BLAST]: checkEnvVar("BLAST_RPC"),
  [ChainSlug.BSC_TESTNET]: checkEnvVar("BSC_TESTNET_RPC"),
  [ChainSlug.POLYNOMIAL]: checkEnvVar("POLYNOMIAL_RPC"),
  [ChainSlug.SYNDR]: checkEnvVar("SYNDR_RPC"),
};
