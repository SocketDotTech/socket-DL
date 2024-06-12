import { arbL3Chains, opStackL2Chain, polygonCDKChains } from "../../../src";
import { ChainSlug } from "../../../src/enums/chainSlug";

import {
  FinalityBucket,
  ChainFinalityType,
  ChainFinalityInfo,
} from "../../../src/socket-types";
import { chainsWithZeroBlockFinality } from "./zeroBlockFinalityChains";


const zeroBlockFinalityDefault = {
  type: ChainFinalityType.time,
  defaultBucket: FinalityBucket.fast,
  [FinalityBucket.fast]:30,
  [FinalityBucket.medium]:60,
  [FinalityBucket.slow]:120
};

const polygonCDKChainsDefault = {
  type: ChainFinalityType.block,
  defaultBucket: FinalityBucket.fast,
  [FinalityBucket.fast]: 1,
  [FinalityBucket.medium]: 10,
  [FinalityBucket.slow]:20,
};

const opStackL2ChainDefault = {
  type: ChainFinalityType.block,
  defaultBucket: FinalityBucket.fast,
  [FinalityBucket.fast]:1,
  [FinalityBucket.medium]:10,
  [FinalityBucket.slow]:20,
};

const arbL3ChainsDefault = {
  type: ChainFinalityType.block,
  defaultBucket: FinalityBucket.fast,
  [FinalityBucket.fast]:1,
  [FinalityBucket.medium]:10,
  [FinalityBucket.slow]: 20,
};

const defaultFinality = {
  type: ChainFinalityType.block,
  defaultBucket: FinalityBucket.fast,
  [FinalityBucket.fast]:1,
  [FinalityBucket.medium]:10,
  [FinalityBucket.slow]:20,
};

export const finalityOverrides: {
  [chainSlug in ChainSlug]?: ChainFinalityInfo;
} = {
  [ChainSlug.AEVO]: {
    type: ChainFinalityType.block,
    defaultBucket: FinalityBucket.fast,
    [FinalityBucket.fast]:2,
    [FinalityBucket.medium]:10,
    [FinalityBucket.slow]:20,
  },

  [ChainSlug.LYRA]: {
    type: ChainFinalityType.block,
    defaultBucket: FinalityBucket.fast,
    [FinalityBucket.fast]:2,
    [FinalityBucket.medium]:10,
    [FinalityBucket.slow]:20,
  },
  [ChainSlug.OPTIMISM]: {
    type: ChainFinalityType.block,
    defaultBucket: FinalityBucket.fast,
    [FinalityBucket.fast]:15,
    [FinalityBucket.medium]:30,
    [FinalityBucket.slow]:40,
  },
  [ChainSlug.POLYGON_MAINNET]: {
    type: ChainFinalityType.block,
    defaultBucket: FinalityBucket.slow,
    [FinalityBucket.fast]:50,
    [FinalityBucket.medium]:150,
    [FinalityBucket.slow]:256,
  },
  [ChainSlug.MAINNET]: {
    type: ChainFinalityType.block,
    defaultBucket: FinalityBucket.slow,
    [FinalityBucket.fast]:6,
    [FinalityBucket.medium]:10,
    [FinalityBucket.slow]:18,
  },
  [ChainSlug.MODE]: {
    type: ChainFinalityType.block,
    defaultBucket: FinalityBucket.fast,
    [FinalityBucket.fast]:2,
    [FinalityBucket.medium]:10,
    [FinalityBucket.slow]:20,
  },
};

export const getFinality = (chainSlug: ChainSlug): ChainFinalityInfo => {
  let finalityOverride = finalityOverrides[chainSlug];
  // if override exists, return it
  if (finalityOverride) return finalityOverride;

  if (chainsWithZeroBlockFinality.includes(chainSlug)) {
    return zeroBlockFinalityDefault;
  }
  if (polygonCDKChains.includes(chainSlug)) {
    return polygonCDKChainsDefault;
  }
  if (opStackL2Chain.includes(chainSlug)) {
    return opStackL2ChainDefault;
  }
  if (arbL3Chains.includes(chainSlug)) {
    return arbL3ChainsDefault;
  }
  return defaultFinality;
};
