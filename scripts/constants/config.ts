import { ChainKey, IntegrationTypes, NativeSwitchboard } from "../../src/types";

export const maxAllowedPacketLength = 10;

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
  [ChainKey.AEVO]: 7200,
  [ChainKey.LYRA_TESTNET]: 7200,
  [ChainKey.LYRA]: 7200,
  [ChainKey.XAI_TESTNET]: 7200,
};

export const getDefaultIntegrationType = (
  chain: ChainKey,
  sibling: ChainKey
): IntegrationTypes => {
  return switchboards?.[chain]?.[sibling]
    ? IntegrationTypes.native
    : IntegrationTypes.fast2;
  // : IntegrationTypes.fast; // revert back this when migration done
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
