import {
  ChainSlug,
  IntegrationTypes,
  NativeSwitchboard,
} from "../../src/types";

export const maxAllowedPacketLength = 10;

export const timeout: {
  [key: string]: number;
} = {
  [ChainSlug.BSC_TESTNET]: 7200,
  [ChainSlug.POLYGON_MAINNET]: 7200,
  [ChainSlug.BSC]: 7200,
  [ChainSlug.POLYGON_MUMBAI]: 7200,
  [ChainSlug.ARBITRUM_GOERLI]: 7200,
  [ChainSlug.OPTIMISM_GOERLI]: 7200,
  [ChainSlug.GOERLI]: 7200,
  [ChainSlug.HARDHAT]: 7200,
  [ChainSlug.ARBITRUM]: 7200,
  [ChainSlug.OPTIMISM]: 7200,
  [ChainSlug.MAINNET]: 7200,
  [ChainSlug.SEPOLIA]: 7200,
  [ChainSlug.AEVO_TESTNET]: 7200,
  [ChainSlug.AEVO]: 7200,
  [ChainSlug.LYRA_TESTNET]: 7200,
  [ChainSlug.LYRA]: 7200,
  [ChainSlug.XAI_TESTNET]: 7200,
  [ChainSlug.SX_NETWORK_TESTNET]: 7200,
};

export const getDefaultIntegrationType = (
  chain: ChainSlug,
  sibling: ChainSlug
): IntegrationTypes => {
  return switchboards?.[chain]?.[sibling]
    ? IntegrationTypes.native
    : IntegrationTypes.fast2;
  // : IntegrationTypes.fast; // revert back this when migration done
};

export const switchboards = {
  [ChainSlug.ARBITRUM_GOERLI]: {
    [ChainSlug.GOERLI]: {
      switchboard: NativeSwitchboard.ARBITRUM_L2,
    },
  },
  [ChainSlug.ARBITRUM]: {
    [ChainSlug.MAINNET]: {
      switchboard: NativeSwitchboard.ARBITRUM_L2,
    },
  },
  [ChainSlug.OPTIMISM]: {
    [ChainSlug.MAINNET]: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
  },
  [ChainSlug.OPTIMISM_GOERLI]: {
    [ChainSlug.GOERLI]: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
  },
  [ChainSlug.POLYGON_MAINNET]: {
    [ChainSlug.MAINNET]: {
      switchboard: NativeSwitchboard.POLYGON_L2,
    },
  },
  [ChainSlug.POLYGON_MUMBAI]: {
    [ChainSlug.GOERLI]: {
      switchboard: NativeSwitchboard.POLYGON_L2,
    },
  },
  [ChainSlug.GOERLI]: {
    [ChainSlug.ARBITRUM_GOERLI]: {
      switchboard: NativeSwitchboard.ARBITRUM_L1,
    },
    [ChainSlug.OPTIMISM_GOERLI]: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
    [ChainSlug.POLYGON_MUMBAI]: {
      switchboard: NativeSwitchboard.POLYGON_L1,
    },
  },
  [ChainSlug.MAINNET]: {
    [ChainSlug.ARBITRUM]: {
      switchboard: NativeSwitchboard.ARBITRUM_L1,
    },
    [ChainSlug.OPTIMISM]: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
    [ChainSlug.POLYGON_MAINNET]: {
      switchboard: NativeSwitchboard.POLYGON_L1,
    },
  },
};
