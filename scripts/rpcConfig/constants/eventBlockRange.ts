import { ChainSlug } from "../../../src/enums/chainSlug";

export const getEventBlockRange = (
  chainSlug: ChainSlug
): number | undefined => {
  return eventBlockRangeOverrides[chainSlug];
};

export const eventBlockRangeOverrides: {
  [chainSlug in ChainSlug]?: number;
} = {
  [ChainSlug.HYPEREVM]: 1000,
  [ChainSlug.MONAD]: 1000
};
