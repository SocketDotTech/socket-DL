import { ChainSlug } from "./chainSlug";
import { NativeTokens } from "./native-tokens";

export const Currency = {
  [ChainSlug.BSC]: NativeTokens.binancecoin,
  [ChainSlug.POLYGON_MAINNET]: NativeTokens["matic-network"],
  [ChainSlug.SX_NETWORK_TESTNET]: NativeTokens["sx-network-2"],
  [ChainSlug.SX_NETWORK]: NativeTokens["sx-network-2"],
  [ChainSlug.MANTLE]: NativeTokens.mantle,
  [ChainSlug.BSC_TESTNET]: NativeTokens["binancecoin"],
};
