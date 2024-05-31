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

export const prodVersion = "prod-1.0.18";
export const devVersion = "dev-1.0.1";

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
  [ChainSlug.BOB]: checkEnvVar("BOB_RPC"),
  [ChainSlug.KINTO]: checkEnvVar("KINTO_RPC"),
  [ChainSlug.KINTO_DEVNET]: checkEnvVar("KINTO_DEVNET_RPC"),
  [ChainSlug.CDK_TESTNET]: checkEnvVar("CDK_TESTNET_RPC"),
  [ChainSlug.SIPHER_FUNKI_TESTNET]: checkEnvVar("SIPHER_FUNKI_TESTNET_RPC"),
  [ChainSlug.WINR]: checkEnvVar("WINR_RPC"),
  [ChainSlug.BLAST]: checkEnvVar("BLAST_RPC"),
};

export const explorers = {
  [ChainSlug.AEVO]: "https://explorer.aevo.xyz",
  [ChainSlug.LYRA]: "https://explorer.lyra.finance",
  [ChainSlug.HOOK]: "https://hook.calderaexplorer.xyz",
  [ChainSlug.MANTLE]: "https://explorer.mantle.xyz",
  [ChainSlug.REYA]: "https://explorer.reya.network",
  [ChainSlug.SIPHER_FUNKI_TESTNET]: "https://sepolia-sandbox.funkichain.com",
  [ChainSlug.WINR]: "https://explorerl2new-winr-mainnet-0.t.conduit.xyz",
  [ChainSlug.BLAST]: "https://blastscan.io",
};

export const icons = {
  [ChainSlug.AEVO]: "",
  [ChainSlug.LYRA]: "",
  [ChainSlug.HOOK]: "",
  [ChainSlug.MANTLE]: "",
  [ChainSlug.REYA]: "",
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
  [ChainSlug.SX_NETWORK_TESTNET]: 0,
  [ChainSlug.SX_NETWORK]: 0,
  [ChainSlug.MODE_TESTNET]: 1,
  [ChainSlug.VICTION_TESTNET]: 1,
  [ChainSlug.CDK_TESTNET]: 1,
  [ChainSlug.ARBITRUM_SEPOLIA]: 1,
  [ChainSlug.OPTIMISM_SEPOLIA]: 1,
  [ChainSlug.SEPOLIA]: 1,
  [ChainSlug.ANCIENT8_TESTNET]: 1,
  [ChainSlug.ANCIENT8_TESTNET2]: 1,
  [ChainSlug.HOOK_TESTNET]: 0,
  [ChainSlug.HOOK]: 0,
  [ChainSlug.PARALLEL]: 1,
  [ChainSlug.MANTLE]: 1,
  [ChainSlug.REYA_CRONOS]: 0,
  [ChainSlug.REYA]: 0,
  [ChainSlug.SYNDR_SEPOLIA_L3]: 0,
  [ChainSlug.POLYNOMIAL_TESTNET]: 0,
  [ChainSlug.BOB]: 0,
  [ChainSlug.KINTO]: 0,
  [ChainSlug.KINTO_DEVNET]: 0,
  [ChainSlug.SIPHER_FUNKI_TESTNET]: 0,
  [ChainSlug.WINR]: 0,
  [ChainSlug.BLAST]: 0,
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
  // ChainSlug.SX_NETWORK,
  ChainSlug.AEVO_TESTNET,
  ChainSlug.SEPOLIA,
  ChainSlug.LYRA_TESTNET,
  // ChainSlug.SX_NETWORK_TESTNET,
  ChainSlug.ARBITRUM_SEPOLIA,
  ChainSlug.OPTIMISM_SEPOLIA,
  // ChainSlug.MODE_TESTNET,
  ChainSlug.BASE,
  ChainSlug.MODE,
  // ChainSlug.ANCIENT8_TESTNET2,
  ChainSlug.HOOK_TESTNET,
  ChainSlug.REYA_CRONOS,
  ChainSlug.SYNDR_SEPOLIA_L3,
  ChainSlug.POLYNOMIAL_TESTNET,
  ChainSlug.BOB,
  ChainSlug.KINTO,
  ChainSlug.KINTO_DEVNET,
  ChainSlug.SIPHER_FUNKI_TESTNET,
  ChainSlug.WINR,
  ChainSlug.BLAST,
];

export const prodFeesUpdaterSupportedChainSlugs = (): ChainSlug[] => {
  const feesUpdaterSupportedChainSlugs = [];
  MainnetIds.forEach((m) => {
    if (prodBatcherSupportedChainSlugs.includes(m)) {
      feesUpdaterSupportedChainSlugs.push(m);
    }
  });

  return [
    ...feesUpdaterSupportedChainSlugs,
    ChainSlug.POLYNOMIAL_TESTNET,
    ChainSlug.KINTO_DEVNET,
    ChainSlug.ARBITRUM_SEPOLIA,
  ];
};
