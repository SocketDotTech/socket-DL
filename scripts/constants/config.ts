import { ChainSlug, IntegrationTypes, NativeSwitchboard } from "../../src";
import chainConfig from "../../chainConfig.json";

const TIMEOUT = 7200;
export const maxAllowedPacketLength = 10;

// return chain specific timeout if present else default value
export const timeout = (chain: number): number => {
  if (chainConfig[chain]) {
    if (chainConfig[chain].timeout && !isNaN(chainConfig[chain].timeout!))
      return chainConfig[chain].timeout!;
  }
  return TIMEOUT;
};

export const getDefaultIntegrationType = (
  chain: ChainSlug,
  sibling: ChainSlug
): IntegrationTypes => {
  return switchboards?.[chain]?.[sibling]
    ? IntegrationTypes.native
    : IntegrationTypes.fast;
};

export const switchboards = {
  [ChainSlug.ARBITRUM_SEPOLIA]: {
    [ChainSlug.SEPOLIA]: {
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
  [ChainSlug.OPTIMISM_SEPOLIA]: {
    [ChainSlug.SEPOLIA]: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
  },
  [ChainSlug.LYRA_TESTNET]: {
    [ChainSlug.SEPOLIA]: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
  },
  // [ChainSlug.LYRA]: {
  //   [ChainSlug.MAINNET]: {
  //     switchboard: NativeSwitchboard.OPTIMISM,
  //   },
  // },
  [ChainSlug.POLYGON_MAINNET]: {
    [ChainSlug.MAINNET]: {
      switchboard: NativeSwitchboard.POLYGON_L2,
    },
  },
  [ChainSlug.SEPOLIA]: {
    [ChainSlug.ARBITRUM_SEPOLIA]: {
      switchboard: NativeSwitchboard.ARBITRUM_L1,
    },
    [ChainSlug.OPTIMISM_SEPOLIA]: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
    [ChainSlug.LYRA_TESTNET]: {
      switchboard: NativeSwitchboard.OPTIMISM,
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
    [ChainSlug.LYRA]: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
  },
};
