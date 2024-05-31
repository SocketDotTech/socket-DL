import { ChainSlug } from "./chainSlug";

// add coingecko token id here
export enum NativeTokens {
  "ethereum" = "ethereum",
  "matic-network" = "matic-network",
  "binancecoin" = "binancecoin",
  "sx-network-2" = "sx-network-2",
  "mantle" = "mantle",
  "no-token" = "no-token",
  "winr" = "winr-protocol",
}

export const getCurrency = (chainSlug: ChainSlug) => {
  switch (chainSlug) {
    case ChainSlug.BSC:
    case ChainSlug.BSC_TESTNET:
      return NativeTokens.binancecoin;

    case ChainSlug.POLYGON_MAINNET:
      return NativeTokens["matic-network"];

    case ChainSlug.SX_NETWORK_TESTNET:
    case ChainSlug.SX_NETWORK:
      return NativeTokens["sx-network-2"];

    case ChainSlug.MANTLE:
      return NativeTokens.mantle;

    case ChainSlug.WINR:
      return NativeTokens.winr;

    default:
      return NativeTokens.ethereum;
  }
};
