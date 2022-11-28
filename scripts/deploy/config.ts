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
      "configForCounter": fastIntegration
    },
    {
      "remoteChain": "bsc-testnet",
      "config": [fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": fastIntegration
    },
  ],
  "bsc-testnet": [
    {
      "remoteChain": "goerli",
      "config": [fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": fastIntegration
    },
    {
      "remoteChain": "arbitrum-goerli",
      "config": [fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": fastIntegration
    },
    {
      "remoteChain": "optimism-goerli",
      "config": [fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": fastIntegration
    },
    {
      "remoteChain": "polygon-mumbai",
      "config": [fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": fastIntegration
    },
  ],
  "polygon-mainnet": [
    {
      "remoteChain": "bsc",
      "config": [fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": fastIntegration
    },
  ],
  bsc: [
    {
      "remoteChain": "polygon-mainnet",
      "config": [fastIntegration, IntegrationTypes.slowIntegration],
      "configForCounter": fastIntegration
    },
  ]
}