import {
  ChainFinalityInfo,
  ChainSlug,
  FinalityBucket,
  FinalityType,
} from "../../../src";

export const finality: {
  [chainSlug in ChainSlug]?: ChainFinalityInfo;
} = {
  [ChainSlug.AEVO]: {
    type: FinalityType.block,
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
  [ChainSlug.ARBITRUM]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.LYRA]: {
    type: FinalityType.block,
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
    type: FinalityType.block,
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
  [ChainSlug.BSC]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.POLYGON_MAINNET]: {
    type: FinalityType.block,
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
    type: FinalityType.block,
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
  [ChainSlug.BASE]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.MODE]: {
    type: FinalityType.block,
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
  [ChainSlug.ARBITRUM_GOERLI]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.AEVO_TESTNET]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.LYRA_TESTNET]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.OPTIMISM_GOERLI]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.GOERLI]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.XAI_TESTNET]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.SX_NETWORK_TESTNET]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.SX_NETWORK]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.MODE_TESTNET]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.VICTION_TESTNET]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.CDK_TESTNET]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.ARBITRUM_SEPOLIA]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.OPTIMISM_SEPOLIA]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.SEPOLIA]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.ANCIENT8_TESTNET]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.ANCIENT8_TESTNET2]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.HOOK_TESTNET]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.HOOK]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.PARALLEL]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.MANTLE]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.REYA_CRONOS]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.REYA]: {
    type: FinalityType.time,
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
  },
  [ChainSlug.SYNDR_SEPOLIA_L3]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.POLYNOMIAL_TESTNET]: {
    type: FinalityType.block,
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
  },
  [ChainSlug.BOB]: {
    type: FinalityType.time,
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
  },
  [ChainSlug.KINTO]: {
    type: FinalityType.time,
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
  },
  [ChainSlug.KINTO_DEVNET]: {
    type: FinalityType.time,
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
  },
  [ChainSlug.SIPHER_FUNKI_TESTNET]: {
    type: FinalityType.time,
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
  },
  [ChainSlug.WINR]: {
    type: FinalityType.time,
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
  },
  [ChainSlug.BLAST]: {
    type: FinalityType.time,
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
  },
  [ChainSlug.BSC_TESTNET]: {
    type: FinalityType.block,
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
  },
};
