import { ChainSlug, IntegrationTypes, NativeSwitchboard } from "../../src";
import { chainConfig } from "../../chainConfig";

export const maxAllowedPacketLength = 10;

const TIMEOUT = 7200;

// return chain specific timeout if present else default value
export const timeout = (chain: number): number => {
  if (chainConfig[chain] && chainConfig[chain].timeout)
    return chainConfig[chain].timeout;
  return TIMEOUT;
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
