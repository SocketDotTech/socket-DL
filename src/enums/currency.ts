import { ChainSlug } from "./chainSlug";
import { NativeTokens } from "./native-tokens";

export const Currency = {
  [ChainSlug.BSC]: NativeTokens.binancecoin,
  [ChainSlug.POLYGON_MAINNET]: NativeTokens["matic-network"],
  [ChainSlug.SX_NETWORK_TESTNET]: NativeTokens["sx-network-2"],
  [ChainSlug.SX_NETWORK]: NativeTokens["sx-network-2"],
  [ChainSlug.MANTLE]: NativeTokens.mantle,
  [ChainSlug.BSC_TESTNET]: NativeTokens["binancecoin"],
  [ChainSlug.WINR]: NativeTokens["winr"],
  [ChainSlug.NEOX_TESTNET]: NativeTokens["gas"],
  [ChainSlug.NEOX_T4_TESTNET]: NativeTokens["gas"],
  [ChainSlug.NEOX]: NativeTokens["gas"],
  [ChainSlug.GNOSIS]: NativeTokens["dai"],
  [ChainSlug.AVALANCHE]: NativeTokens["avalanche-2"],
  [ChainSlug.XLAYER]: NativeTokens["okb"],
  [ChainSlug.POLTER_TESTNET]: NativeTokens["aavegotchi"],
  [ChainSlug.POLYGON_AMOY]: NativeTokens["matic-network"],
  [ChainSlug.OPBNB]: NativeTokens["binancecoin"],
  [ChainSlug.GEIST]: NativeTokens["aavegotchi"],
  [ChainSlug.SONIC]: NativeTokens["fantom"],
  [ChainSlug.BERA]: NativeTokens["berachain-bera"],
  [ChainSlug.MONAD_TESTNET]: NativeTokens["monad"],
  [ChainSlug.PLUME]: NativeTokens["plume"],
  [ChainSlug.HYPEREVM]: NativeTokens["hyperliquid"],
};
