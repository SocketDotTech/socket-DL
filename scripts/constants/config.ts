import { IntegrationTypes, NativeSwitchboard } from "../../src/types";
import { ChainKey } from "./networks";

export const socketOwner = "0x5fD7D0d6b91CC4787Bcb86ca47e0Bd4ea0346d34";

export const timeout: {
  [key: string]: number;
} = {
  "bsc-testnet": 7200,
  "polygon-mainnet": 7200,
  bsc: 7200,
  "polygon-mumbai": 7200,
  "arbitrum-goerli": 7200,
  "optimism-goerli": 7200,
  goerli: 7200,
  hardhat: 7200,
  arbitrum: 7200,
  optimism: 7200,
  mainnet: 7200,
};

export const sealGasLimit: {
  [key: string]: number;
} = {
  "bsc-testnet": 300000,
  "polygon-mainnet": 300000,
  bsc: 300000,
  "polygon-mumbai": 300000,
  "arbitrum-goerli": 300000,
  "optimism-goerli": 300000,
  goerli: 300000,
  hardhat: 300000,
  arbitrum: 300000,
  optimism: 300000,
  mainnet: 300000,
};

export const proposeGasLimit: {
  [key: string]: number;
} = {
  "bsc-testnet": 80000,
  "polygon-mainnet": 80000,
  bsc: 80000,
  "polygon-mumbai": 80000,
  "arbitrum-goerli": 1000000,
  "optimism-goerli": 80000,
  goerli: 80000,
  hardhat: 80000,
  arbitrum: 1000000,
  optimism: 80000,
  mainnet: 80000,
};

export const attestGasLimit: {
  [key: string]: number;
} = {
  "bsc-testnet": 80000,
  "polygon-mainnet": 80000,
  bsc: 80000,
  "polygon-mumbai": 80000,
  "arbitrum-goerli": 1000000,
  "optimism-goerli": 80000,
  goerli: 80000,
  hardhat: 80000,
  arbitrum: 1000000,
  optimism: 80000,
  mainnet: 80000,
};

export const executionOverhead: {
  [key: string]: number;
} = {
  "bsc-testnet": 40000,
  "polygon-mainnet": 40000,
  bsc: 40000,
  "polygon-mumbai": 40000,
  "arbitrum-goerli": 500000,
  "optimism-goerli": 40000,
  goerli: 40000,
  hardhat: 40000,
  arbitrum: 500000,
  optimism: 40000,
  mainnet: 40000,
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
  "arbitrum-goerli": {
    goerli: {
      switchboard: NativeSwitchboard.ARBITRUM_L2,
    },
  },
  arbitrum: {
    mainnet: {
      switchboard: NativeSwitchboard.ARBITRUM_L2,
    },
  },
  optimism: {
    mainnet: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
  },
  "optimism-goerli": {
    goerli: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
  },
  "polygon-mainnet": {
    mainnet: {
      switchboard: NativeSwitchboard.POLYGON_L2,
    },
  },
  "polygon-mumbai": {
    goerli: {
      switchboard: NativeSwitchboard.POLYGON_L2,
    },
  },
  goerli: {
    "arbitrum-goerli": {
      switchboard: NativeSwitchboard.ARBITRUM_L1,
    },
    "optimism-goerli": {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
    "polygon-mumbai": {
      switchboard: NativeSwitchboard.POLYGON_L1,
    },
  },
  mainnet: {
    arbitrum: {
      switchboard: NativeSwitchboard.ARBITRUM_L1,
    },
    optimism: {
      switchboard: NativeSwitchboard.OPTIMISM,
    },
    "polygon-mainnet": {
      switchboard: NativeSwitchboard.POLYGON_L1,
    },
  },
};
