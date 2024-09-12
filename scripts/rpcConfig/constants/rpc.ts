import dotenv from "dotenv";
import { ChainSlug } from "../../../src";
import { checkEnvValue } from "@socket.tech/dl-common";
dotenv.config();

export const rpcs = {
  [ChainSlug.AEVO]: checkEnvValue("AEVO_RPC"),
  [ChainSlug.ARBITRUM]: checkEnvValue("ARBITRUM_RPC"),
  [ChainSlug.LYRA]: checkEnvValue("LYRA_RPC"),
  [ChainSlug.OPTIMISM]: checkEnvValue("OPTIMISM_RPC"),
  [ChainSlug.BSC]: checkEnvValue("BSC_RPC"),
  [ChainSlug.POLYGON_MAINNET]: checkEnvValue("POLYGON_MAINNET_RPC"),
  [ChainSlug.MAINNET]: checkEnvValue("MAINNET_RPC"),
  [ChainSlug.PARALLEL]: checkEnvValue("PARALLEL_RPC"),
  [ChainSlug.HOOK]: checkEnvValue("HOOK_RPC"),
  [ChainSlug.MANTLE]: checkEnvValue("MANTLE_RPC"),
  [ChainSlug.REYA]: checkEnvValue("REYA_RPC"),
  [ChainSlug.ARBITRUM_SEPOLIA]: checkEnvValue("ARBITRUM_SEPOLIA_RPC"),
  [ChainSlug.OPTIMISM_SEPOLIA]: checkEnvValue("OPTIMISM_SEPOLIA_RPC"),
  [ChainSlug.SEPOLIA]: checkEnvValue("SEPOLIA_RPC"),
  [ChainSlug.ARBITRUM_GOERLI]: checkEnvValue("ARBITRUM_GOERLI_RPC"),
  [ChainSlug.AEVO_TESTNET]: checkEnvValue("AEVO_TESTNET_RPC"),
  [ChainSlug.LYRA_TESTNET]: checkEnvValue("LYRA_TESTNET_RPC"),
  [ChainSlug.OPTIMISM_GOERLI]: checkEnvValue("OPTIMISM_GOERLI_RPC"),
  [ChainSlug.GOERLI]: checkEnvValue("GOERLI_RPC"),
  [ChainSlug.XAI_TESTNET]: checkEnvValue("XAI_TESTNET_RPC"),
  [ChainSlug.SX_NETWORK_TESTNET]: checkEnvValue("SXN_TESTNET_RPC"),
  [ChainSlug.SX_NETWORK]: checkEnvValue("SXN_RPC"),
  [ChainSlug.MODE_TESTNET]: checkEnvValue("MODE_TESTNET_RPC"),
  [ChainSlug.VICTION_TESTNET]: checkEnvValue("VICTION_TESTNET_RPC"),
  [ChainSlug.BASE]: checkEnvValue("BASE_RPC"),
  [ChainSlug.MODE]: checkEnvValue("MODE_RPC"),
  [ChainSlug.ANCIENT8_TESTNET]: checkEnvValue("ANCIENT8_TESTNET_RPC"),
  [ChainSlug.ANCIENT8_TESTNET2]: checkEnvValue("ANCIENT8_TESTNET2_RPC"),
  [ChainSlug.HOOK_TESTNET]: checkEnvValue("HOOK_TESTNET_RPC"),
  [ChainSlug.REYA_CRONOS]: checkEnvValue("REYA_CRONOS_RPC"),
  [ChainSlug.SYNDR_SEPOLIA_L3]: checkEnvValue("SYNDR_SEPOLIA_L3_RPC"),
  [ChainSlug.POLYNOMIAL_TESTNET]: checkEnvValue("POLYNOMIAL_TESTNET_RPC"),
  [ChainSlug.BOB]: checkEnvValue("BOB_RPC"),
  [ChainSlug.KINTO]: checkEnvValue("KINTO_RPC"),
  [ChainSlug.KINTO_DEVNET]: checkEnvValue("KINTO_DEVNET_RPC"),
  [ChainSlug.CDK_TESTNET]: checkEnvValue("CDK_TESTNET_RPC"),
  [ChainSlug.SIPHER_FUNKI_TESTNET]: checkEnvValue("SIPHER_FUNKI_TESTNET_RPC"),
  [ChainSlug.WINR]: checkEnvValue("WINR_RPC"),
  [ChainSlug.BLAST]: checkEnvValue("BLAST_RPC"),
  [ChainSlug.BSC_TESTNET]: checkEnvValue("BSC_TESTNET_RPC"),
  [ChainSlug.POLYNOMIAL]: checkEnvValue("POLYNOMIAL_RPC"),
  [ChainSlug.SYNDR]: checkEnvValue("SYNDR_RPC"),
  [ChainSlug.NEOX_TESTNET]: checkEnvValue("NEOX_TESTNET_RPC"),
  [ChainSlug.NEOX_T4_TESTNET]: checkEnvValue("NEOX_T4_TESTNET_RPC"),
  [ChainSlug.NEOX]: checkEnvValue("NEOX_RPC"),
  [ChainSlug.GNOSIS]: checkEnvValue("GNOSIS_RPC"),
  [ChainSlug.LINEA]: checkEnvValue("LINEA_RPC"),
  [ChainSlug.ZKEVM]: checkEnvValue("ZKEVM_RPC"),
  [ChainSlug.AVALANCHE]: checkEnvValue("AVALANCHE_RPC"),
  [ChainSlug.XLAYER]: checkEnvValue("XLAYER_RPC"),
};
