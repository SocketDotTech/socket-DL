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
      return NativeTokens.ethereum;
  }
};
