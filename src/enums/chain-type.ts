import { ChainSlug } from "./chainSlug";

export const opStackL2Chain = [
  ChainSlug.AEVO,
  ChainSlug.AEVO_TESTNET,
  ChainSlug.LYRA,
  ChainSlug.MODE_TESTNET,
  ChainSlug.LYRA_TESTNET,
  ChainSlug.MODE,
  ChainSlug.OPTIMISM,
  ChainSlug.OPTIMISM_SEPOLIA,
  ChainSlug.OPTIMISM_GOERLI,
  ChainSlug.BASE,
  ChainSlug.MANTLE,
  ChainSlug.POLYNOMIAL_TESTNET,
];

export const arbL3Chains = [
  ChainSlug.HOOK_TESTNET,
  ChainSlug.HOOK,
  ChainSlug.SYNDR_SEPOLIA_L3,
];

export const arbChains = [
  ChainSlug.ARBITRUM,
  ChainSlug.ARBITRUM_GOERLI,
  ChainSlug.ARBITRUM_SEPOLIA,
  ChainSlug.PARALLEL,
];

export const polygonCDKChains = [
  ChainSlug.CDK_TESTNET,
  ChainSlug.ANCIENT8_TESTNET2,
  ChainSlug.SX_NETWORK_TESTNET,
  ChainSlug.SX_NETWORK,
  ChainSlug.XAI_TESTNET,
];

// chains having constant gas limits
export const ethLikeChains = [
  ChainSlug.MAINNET,
  ChainSlug.BSC,
  ChainSlug.BSC_TESTNET,
  ChainSlug.POLYGON_MAINNET,
  ChainSlug.POLYGON_MUMBAI,
  ChainSlug.SEPOLIA,
  ChainSlug.SX_NETWORK,
  ChainSlug.SX_NETWORK_TESTNET,
  ChainSlug.ANCIENT8_TESTNET,
  ChainSlug.ANCIENT8_TESTNET2,
  ChainSlug.REYA_CRONOS,
  ChainSlug.REYA,
  ChainSlug.BSC_TESTNET,
  ChainSlug.GOERLI,
  ChainSlug.VICTION_TESTNET,
  ChainSlug.SYNDR_SEPOLIA_L3,
];
