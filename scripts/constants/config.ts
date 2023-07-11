import { ChainKey, IntegrationTypes, NativeSwitchboard } from "../../src/types";

export const timeout: {
  [key: string]: number;
} = {
  [ChainKey.BSC_TESTNET]: 7200,
  [ChainKey.POLYGON_MAINNET]: 7200,
  [ChainKey.BSC]: 7200,
  [ChainKey.POLYGON_MUMBAI]: 7200,
  [ChainKey.ARBITRUM_GOERLI]: 7200,
  [ChainKey.OPTIMISM_GOERLI]: 7200,
  [ChainKey.GOERLI]: 7200,
  [ChainKey.HARDHAT]: 7200,
  [ChainKey.ARBITRUM]: 7200,
  [ChainKey.OPTIMISM]: 7200,
  [ChainKey.MAINNET]: 7200,
  [ChainKey.SEPOLIA]: 7200,
  [ChainKey.AEVO_TESTNET]: 7200,
};

export const attestGasLimit: {
  [key: string]: number;
} = {
  [ChainKey.BSC_TESTNET]: 80000,
  [ChainKey.POLYGON_MAINNET]: 80000,
  [ChainKey.BSC]: 80000,
  [ChainKey.POLYGON_MUMBAI]: 80000,
  [ChainKey.ARBITRUM_GOERLI]: 1000000,
  [ChainKey.OPTIMISM_GOERLI]: 80000,
  [ChainKey.GOERLI]: 80000,
  [ChainKey.HARDHAT]: 80000,
  [ChainKey.ARBITRUM]: 1000000,
  [ChainKey.OPTIMISM]: 80000,
  [ChainKey.MAINNET]: 80000,
  [ChainKey.SEPOLIA]: 80000,
  [ChainKey.AEVO_TESTNET]: 80000,
};

export const executionOverhead: {
  [key: string]: number;
} = {
  [ChainKey.BSC_TESTNET]: 40000,
  [ChainKey.POLYGON_MAINNET]: 40000,
  [ChainKey.BSC]: 40000,
  [ChainKey.POLYGON_MUMBAI]: 40000,
  [ChainKey.ARBITRUM_GOERLI]: 500000,
  [ChainKey.OPTIMISM_GOERLI]: 40000,
  [ChainKey.GOERLI]: 40000,
  [ChainKey.HARDHAT]: 40000,
  [ChainKey.ARBITRUM]: 500000,
  [ChainKey.OPTIMISM]: 40000,
  [ChainKey.MAINNET]: 40000,
  [ChainKey.SEPOLIA]: 40000,
  [ChainKey.AEVO_TESTNET]: 40000,
};

export const getDefaultIntegrationType = (
  chain: ChainKey,
  sibling: ChainKey
): IntegrationTypes => {
  return switchboards?.[chain]?.[sibling]
    ? IntegrationTypes.native
    : IntegrationTypes.fast;
};

export const switchboards = {
  [ChainKey.ARBITRUM_GOERLI]: {
    [ChainKey.GOERLI]: {
      switchboard: NativeSwitchboard.ARBITRUM_L2,
    },
  },
  [ChainKey.ARBITRUM]: {
    [ChainKey.MAINNET]: {
      switchboard: NativeSwitchboard.ARBITRUM_L2,
    },
  },
  [ChainKey.OPTIMISM]: {
    [ChainKey.MAINNET]: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
  },
  [ChainKey.OPTIMISM_GOERLI]: {
    [ChainKey.GOERLI]: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
  },
  [ChainKey.POLYGON_MAINNET]: {
    [ChainKey.MAINNET]: {
      switchboard: NativeSwitchboard.POLYGON_L2,
    },
  },
  [ChainKey.POLYGON_MUMBAI]: {
    [ChainKey.GOERLI]: {
      switchboard: NativeSwitchboard.POLYGON_L2,
    },
  },
  [ChainKey.GOERLI]: {
    [ChainKey.ARBITRUM_GOERLI]: {
      switchboard: NativeSwitchboard.ARBITRUM_L1,
    },
    [ChainKey.OPTIMISM_GOERLI]: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
    [ChainKey.POLYGON_MUMBAI]: {
      switchboard: NativeSwitchboard.POLYGON_L1,
    },
  },
  [ChainKey.MAINNET]: {
    [ChainKey.ARBITRUM]: {
      switchboard: NativeSwitchboard.ARBITRUM_L1,
    },
    [ChainKey.OPTIMISM]: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
    [ChainKey.POLYGON_MAINNET]: {
      switchboard: NativeSwitchboard.POLYGON_L1,
    },
  },
};
