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
    [FinalityBucket.low]: 64,
    [FinalityBucket.medium]: 256,
    [FinalityBucket.high]: 1000,
  },
  [ChainSlug.NEOX_TESTNET]: {
    [FinalityBucket.low]: 1,
    [FinalityBucket.medium]: 10,
    [FinalityBucket.high]: 100,
  },
  [ChainSlug.NEOX_T4_TESTNET]: {
    [FinalityBucket.low]: 1,
    [FinalityBucket.medium]: 10,
    [FinalityBucket.high]: 100,
  },
  [ChainSlug.NEOX]: {
    [FinalityBucket.low]: 1,
    [FinalityBucket.medium]: 10,
    [FinalityBucket.high]: 100,
  },
  [ChainSlug.LINEA]: {
    [FinalityBucket.low]: 1,
    [FinalityBucket.medium]: 10,
    [FinalityBucket.high]: 100,
  },
  [ChainSlug.ZERO]: {
    [FinalityBucket.low]: 1,
    [FinalityBucket.medium]: 2000,
    [FinalityBucket.high]: 3000,
  },
  [ChainSlug.ZKSYNC]: {
    [FinalityBucket.low]: 1,
    [FinalityBucket.medium]: 2000,
    [FinalityBucket.high]: 3000,
  },
};
