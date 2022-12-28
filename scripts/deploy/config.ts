import { IntegrationTypes } from "../../src/types";

export const config = {
  "goerli": [
    {
      "remoteChain": "arbitrum-goerli",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration, IntegrationTypes.nativeIntegration],
      "configForCounter": IntegrationTypes.nativeIntegration
    },
    {
      "remoteChain": "optimism-goerli",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration, IntegrationTypes.nativeIntegration],
      "configForCounter": IntegrationTypes.nativeIntegration
    },
    {
      "remoteChain": "polygon-mumbai",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration, IntegrationTypes.nativeIntegration],
      "configForCounter": IntegrationTypes.nativeIntegration
    },
    {
      "remoteChain": "bsc-testnet",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
  ],
  "arbitrum-goerli": [
    {
      "remoteChain": "goerli",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration, IntegrationTypes.nativeIntegration],
      "configForCounter": IntegrationTypes.nativeIntegration
    },
    {
      "remoteChain": "optimism-goerli",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "polygon-mumbai",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "bsc-testnet",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
  ],
  "optimism-goerli": [
    {
      "remoteChain": "goerli",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration, IntegrationTypes.nativeIntegration],
      "configForCounter": IntegrationTypes.nativeIntegration
    },
    {
      "remoteChain": "arbitrum-goerli",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "polygon-mumbai",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "bsc-testnet",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
  ],
  "polygon-mumbai": [
    {
      "remoteChain": "goerli",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration, IntegrationTypes.nativeIntegration],
      "configForCounter": IntegrationTypes.nativeIntegration
    },
    {
      "remoteChain": "arbitrum-goerli",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "optimism-goerli",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "bsc-testnet",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
  ],
  "bsc-testnet": [
    {
      "remoteChain": "goerli",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "arbitrum-goerli",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "optimism-goerli",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "polygon-mumbai",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
  ],
  bsc: [
    {
      "remoteChain": "polygon-mainnet",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "optimism",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "arbitrum",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "mainnet",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
  ],
  "polygon-mainnet": [
    {
      "remoteChain": "bsc",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "mainnet",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration, IntegrationTypes.nativeIntegration],
      "configForCounter": IntegrationTypes.nativeIntegration
    },
    {
      "remoteChain": "optimism",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "arbitrum",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
  ],
  mainnet: [
    {
      "remoteChain": "polygon-mainnet",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration, IntegrationTypes.nativeIntegration],
      "configForCounter": IntegrationTypes.nativeIntegration
    },
    {
      "remoteChain": "bsc",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "optimism",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration, IntegrationTypes.nativeIntegration],
      "configForCounter": IntegrationTypes.nativeIntegration
    },
    {
      "remoteChain": "arbitrum",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration, IntegrationTypes.nativeIntegration],
      "configForCounter": IntegrationTypes.nativeIntegration
    },
  ],
  optimism: [
    {
      "remoteChain": "polygon-mainnet",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "mainnet",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration, IntegrationTypes.nativeIntegration],
      "configForCounter": IntegrationTypes.nativeIntegration
    },
    {
      "remoteChain": "bsc",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "arbitrum",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
  ],
  arbitrum: [
    {
      "remoteChain": "polygon-mainnet",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "mainnet",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration, IntegrationTypes.nativeIntegration],
      "configForCounter": IntegrationTypes.nativeIntegration
    },
    {
      "remoteChain": "optimism",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
    {
      "remoteChain": "bsc",
      "config": [IntegrationTypes.fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": IntegrationTypes.fastIntegration
    },
  ]
}