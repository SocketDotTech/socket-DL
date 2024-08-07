import { ChainSlug } from "../../../src/enums/chainSlug";

import { ChainFinalityInfo, FinalityBucket } from "../../../src/socket-types";

export const getFinality = (
  chainSlug: ChainSlug
): ChainFinalityInfo | undefined => {
  return finalityOverrides[chainSlug];
};

export const finalityOverrides: {
  [chainSlug in ChainSlug]?: ChainFinalityInfo;
} = {
  [ChainSlug.POLYGON_MAINNET]: {
    [FinalityBucket.fast]: 64,
    [FinalityBucket.medium]: 256,
    [FinalityBucket.slow]: 1000,
  },
  [ChainSlug.NEOX_TESTNET]: {
    [FinalityBucket.fast]: 1,
    [FinalityBucket.medium]: 10,
    [FinalityBucket.slow]: 100,
  },
  [ChainSlug.NEOX_T4_TESTNET]: {
    [FinalityBucket.fast]: 1,
    [FinalityBucket.medium]: 10,
    [FinalityBucket.slow]: 100,
  },
  [ChainSlug.NEOX]: {
    [FinalityBucket.fast]: 1,
    [FinalityBucket.medium]: 10,
    [FinalityBucket.slow]: 100,
  },
};
