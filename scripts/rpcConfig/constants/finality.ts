import { arbL3Chains, opStackL2Chain, polygonCDKChains } from "../../../src";
import { ChainSlug } from "../../../src/enums/chainSlug";

import {
  FinalityBucket,
  BucketFinalityType,
  ChainFinalityInfo,
} from "../../../src/socket-types";

const chainsWithZeroBlockFinality = [
  ChainSlug.REYA,
  ChainSlug.BOB,
  ChainSlug.KINTO,
  ChainSlug.KINTO_DEVNET,
  ChainSlug.SIPHER_FUNKI_TESTNET,
  ChainSlug.WINR,
  ChainSlug.BLAST,
];

const zeroBlockFinalityDefault = {
  type: BucketFinalityType.time,
  defaultBucket: FinalityBucket.fast,
  [FinalityBucket.fast]: {
    block: 0,
    time: 30,
  },
  [FinalityBucket.medium]: {
    time: 60,
    block: 0,
  },
  [FinalityBucket.slow]: {
    time: 120,
    block: 0,
  },
};

const polygonCDKChainsDefault = {
  type: BucketFinalityType.block,
  defaultBucket: FinalityBucket.fast,
  [FinalityBucket.fast]: {
    block: 1,
    time: 0,
  },
  [FinalityBucket.medium]: {
    block: 10,
    time: 0,
  },
  [FinalityBucket.slow]: {
    block: 20,
    time: 0,
  },
};

const opStackL2ChainDefault = {
  type: BucketFinalityType.block,
  defaultBucket: FinalityBucket.fast,
  [FinalityBucket.fast]: {
    block: 1,
    time: 0,
  },
  [FinalityBucket.medium]: {
    block: 10,
    time: 0,
  },
  [FinalityBucket.slow]: {
    block: 20,
    time: 0,
  },
};

const arbL3ChainsDefault = {
  type: BucketFinalityType.block,
  defaultBucket: FinalityBucket.fast,
  [FinalityBucket.fast]: {
    block: 1,
    time: 0,
  },
  [FinalityBucket.medium]: {
    block: 10,
    time: 0,
  },
  [FinalityBucket.slow]: {
    block: 20,
    time: 0,
  },
};

const defaultFinality = {
  type: BucketFinalityType.block,
  defaultBucket: FinalityBucket.fast,
  [FinalityBucket.fast]: {
    block: 1,
    time: 0,
  },
  [FinalityBucket.medium]: {
    block: 10,
    time: 0,
  },
  [FinalityBucket.slow]: {
    block: 20,
    time: 0,
  },
};

export const finality: {
  [chainSlug in ChainSlug]?: ChainFinalityInfo;
} = {
  [ChainSlug.AEVO]: {
    type: BucketFinalityType.block,
    defaultBucket: FinalityBucket.fast,
    [FinalityBucket.fast]: {
      block: 2,
      time: 0,
    },
    [FinalityBucket.medium]: {
      block: 10,
      time: 0,
    },
    [FinalityBucket.slow]: {
      block: 20,
      time: 0,
    },
  },

  [ChainSlug.LYRA]: {
    type: BucketFinalityType.block,
    defaultBucket: FinalityBucket.fast,
    [FinalityBucket.fast]: {
      block: 2,
      time: 0,
    },
    [FinalityBucket.medium]: {
      block: 10,
      time: 0,
    },
    [FinalityBucket.slow]: {
      block: 20,
      time: 0,
    },
  },
  [ChainSlug.OPTIMISM]: {
    type: BucketFinalityType.block,
    defaultBucket: FinalityBucket.fast,
    [FinalityBucket.fast]: {
      block: 15,
      time: 0,
    },
    [FinalityBucket.medium]: {
      block: 30,
      time: 0,
    },
    [FinalityBucket.slow]: {
      block: 40,
      time: 0,
    },
  },
  [ChainSlug.POLYGON_MAINNET]: {
    type: BucketFinalityType.block,
    defaultBucket: FinalityBucket.slow,
    [FinalityBucket.fast]: {
      block: 50,
      time: 0,
    },
    [FinalityBucket.medium]: {
      block: 150,
      time: 0,
    },
    [FinalityBucket.slow]: {
      block: 256,
      time: 0,
    },
  },
  [ChainSlug.MAINNET]: {
    type: BucketFinalityType.block,
    defaultBucket: FinalityBucket.slow,
    [FinalityBucket.fast]: {
      block: 6,
      time: 0,
    },
    [FinalityBucket.medium]: {
      block: 10,
      time: 0,
    },
    [FinalityBucket.slow]: {
      block: 18,
      time: 0,
    },
  },
  [ChainSlug.MODE]: {
    type: BucketFinalityType.block,
    defaultBucket: FinalityBucket.fast,
    [FinalityBucket.fast]: {
      block: 2,
      time: 0,
    },
    [FinalityBucket.medium]: {
      block: 10,
      time: 0,
    },
    [FinalityBucket.slow]: {
      block: 20,
      time: 0,
    },
  },
};

export const getFinality = (chainSlug: ChainSlug): ChainFinalityInfo => {
  let finalityOverride = finality[chainSlug];
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
