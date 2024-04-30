import { ChainSlug, Currency, NativeTokens } from "./enums";

export const getCurrency = (chainSlug: ChainSlug) => {
  if (Currency[chainSlug]) return Currency[chainSlug];
  return NativeTokens.ethereum;
};
