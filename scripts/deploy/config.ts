import { IntegrationTypes } from "../../src/types";

export const config = {
  goerli: [
    {
      remoteChain: "arbitrum-goerli",
      config: [
        IntegrationTypes.fast,
        IntegrationTypes.optimistic,
        IntegrationTypes.native,
      ],
      configForCounter: IntegrationTypes.native,
    },
    {
      remoteChain: "optimism-goerli",
      config: [
        IntegrationTypes.fast,
        IntegrationTypes.optimistic,
        IntegrationTypes.native,
      ],
      configForCounter: IntegrationTypes.native,
    },
    {
      remoteChain: "polygon-mumbai",
      config: [
        IntegrationTypes.fast,
        IntegrationTypes.optimistic,
        IntegrationTypes.native,
      ],
      configForCounter: IntegrationTypes.native,
    },
    {
      remoteChain: "bsc-testnet",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
  ],
  "arbitrum-goerli": [
    {
      remoteChain: "goerli",
      config: [
        IntegrationTypes.fast,
        IntegrationTypes.optimistic,
        IntegrationTypes.native,
      ],
      configForCounter: IntegrationTypes.native,
    },
    {
      remoteChain: "optimism-goerli",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "polygon-mumbai",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "bsc-testnet",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
  ],
  "optimism-goerli": [
    {
      remoteChain: "goerli",
      config: [
        IntegrationTypes.fast,
        IntegrationTypes.optimistic,
        IntegrationTypes.native,
      ],
      configForCounter: IntegrationTypes.native,
    },
    {
      remoteChain: "arbitrum-goerli",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "polygon-mumbai",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "bsc-testnet",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
  ],
  "polygon-mumbai": [
    {
      remoteChain: "goerli",
      config: [
        IntegrationTypes.fast,
        IntegrationTypes.optimistic,
        IntegrationTypes.native,
      ],
      configForCounter: IntegrationTypes.native,
    },
    {
      remoteChain: "arbitrum-goerli",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "optimism-goerli",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "bsc-testnet",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
  ],
  "bsc-testnet": [
    {
      remoteChain: "goerli",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "arbitrum-goerli",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "optimism-goerli",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "polygon-mumbai",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
  ],
  bsc: [
    {
      remoteChain: "polygon-mainnet",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "optimism",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "arbitrum",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "mainnet",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
  ],
  "polygon-mainnet": [
    {
      remoteChain: "bsc",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "mainnet",
      config: [
        IntegrationTypes.fast,
        IntegrationTypes.optimistic,
        IntegrationTypes.native,
      ],
      configForCounter: IntegrationTypes.native,
    },
    {
      remoteChain: "optimism",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "arbitrum",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
  ],
  mainnet: [
    {
      remoteChain: "polygon-mainnet",
      config: [
        IntegrationTypes.fast,
        IntegrationTypes.optimistic,
        IntegrationTypes.native,
      ],
      configForCounter: IntegrationTypes.native,
    },
    {
      remoteChain: "bsc",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "optimism",
      config: [
        IntegrationTypes.fast,
        IntegrationTypes.optimistic,
        IntegrationTypes.native,
      ],
      configForCounter: IntegrationTypes.native,
    },
    {
      remoteChain: "arbitrum",
      config: [
        IntegrationTypes.fast,
        IntegrationTypes.optimistic,
        IntegrationTypes.native,
      ],
      configForCounter: IntegrationTypes.native,
    },
  ],
  optimism: [
    {
      remoteChain: "polygon-mainnet",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "mainnet",
      config: [
        IntegrationTypes.fast,
        IntegrationTypes.optimistic,
        IntegrationTypes.native,
      ],
      configForCounter: IntegrationTypes.native,
    },
    {
      remoteChain: "bsc",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "arbitrum",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
  ],
  arbitrum: [
    {
      remoteChain: "polygon-mainnet",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "mainnet",
      config: [
        IntegrationTypes.fast,
        IntegrationTypes.optimistic,
        IntegrationTypes.native,
      ],
      configForCounter: IntegrationTypes.native,
    },
    {
      remoteChain: "optimism",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
    {
      remoteChain: "bsc",
      config: [IntegrationTypes.fast, IntegrationTypes.optimistic],
      configForCounter: IntegrationTypes.fast,
    },
  ],
};
