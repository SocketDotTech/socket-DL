import { ChainSlug } from "./chainSlug";

export enum NativeTokens {
  "ethereum" = "ethereum",
  "matic-network" = "matic-network",
  "binancecoin" = "binancecoin",
  "sx-network-2" = "sx-network-2",
  "mantle" = "mantle",
  "no-token" = "0",
}

export const getCurrency = (chainSlug: ChainSlug) => {
  switch (chainSlug) {
    case ChainSlug.AEVO:
    case ChainSlug.AEVO_TESTNET:
    case ChainSlug.ANCIENT8_TESTNET2:
    case ChainSlug.ARBITRUM:
    case ChainSlug.ARBITRUM_GOERLI:
    case ChainSlug.ARBITRUM_SEPOLIA:
    case ChainSlug.BASE:
    case ChainSlug.HOOK:
    case ChainSlug.HOOK_TESTNET:
    case ChainSlug.LYRA:
    case ChainSlug.LYRA_TESTNET:
    case ChainSlug.MAINNET:
    case ChainSlug.MODE:
    case ChainSlug.MODE_TESTNET:
    case ChainSlug.OPTIMISM:
    case ChainSlug.OPTIMISM_GOERLI:
    case ChainSlug.OPTIMISM_SEPOLIA:
    case ChainSlug.PARALLEL:
    case ChainSlug.SEPOLIA:
      return NativeTokens.ethereum;

    case ChainSlug.BSC:
    case ChainSlug.BSC_TESTNET:
      return NativeTokens.binancecoin;

    case ChainSlug.POLYGON_MAINNET:
    case ChainSlug.POLYGON_MUMBAI:
      return NativeTokens["matic-network"];

    case ChainSlug.SX_NETWORK_TESTNET:
    case ChainSlug.SX_NETWORK:
      return NativeTokens["sx-network-2"];

    case ChainSlug.MANTLE:
      return NativeTokens.mantle;

    case ChainSlug.REYA_CRONOS:
    case ChainSlug.REYA:
      return NativeTokens["no-token"];

    default:
      throw new Error("Invalid chainSlug");
  }
};
