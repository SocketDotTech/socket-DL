import { ChainSlug } from "../../../src/enums/chainSlug";

export const getReSyncInterval = (chainSlug: ChainSlug) => {
  return reSyncInterval[chainSlug] ?? 0;
};

export const reSyncInterval = {
  [ChainSlug.POLYGON_MAINNET]: 256,
  [ChainSlug.MAINNET]: 6,
};
