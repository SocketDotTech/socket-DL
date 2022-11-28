import { fastIntegration, nativeBridgeIntegration, slowIntegration } from "../constants"

export const config = {
  "goerli": [
    {
      "remoteChain": "arbitrum-goerli",
      "config": [fastIntegration, slowIntegration, nativeBridgeIntegration],
      "configForCounter": nativeBridgeIntegration
    },
    {
      "remoteChain": "optimism-goerli",
      "config": [fastIntegration, slowIntegration, nativeBridgeIntegration],
      "configForCounter": nativeBridgeIntegration
    },
    {
      "remoteChain": "polygon-mumbai",
      "config": [fastIntegration, slowIntegration, nativeBridgeIntegration],
      "configForCounter": nativeBridgeIntegration
    },
    {
      "remoteChain": "bsc-testnet",
      "config": [fastIntegration, slowIntegration],
      "configForCounter": fastIntegration
    },
  ],
  "arbitrum-goerli": [
    {
      "remoteChain": "goerli",
      "config": [fastIntegration, slowIntegration, nativeBridgeIntegration],
      "configForCounter": nativeBridgeIntegration
    },
    {
      "remoteChain": "optimism-goerli",
      "config": [fastIntegration, slowIntegration],
      "configForCounter": fastIntegration
    },
    {
      "remoteChain": "polygon-mumbai",
      "config": [fastIntegration, slowIntegration],
      "configForCounter": fastIntegration
    },
    {
      "remoteChain": "bsc-testnet",
      "config": [fastIntegration, slowIntegration],
      "configForCounter": fastIntegration
    },
  ],
  "optimism-goerli": [
    {
      "remoteChain": "goerli",
      "config": [fastIntegration, slowIntegration, nativeBridgeIntegration],
      "configForCounter": nativeBridgeIntegration
    },
    {
      "remoteChain": "arbitrum-goerli",
      "config": [fastIntegration, slowIntegration],
      "configForCounter": fastIntegration
    },
    {
      "remoteChain": "polygon-mumbai",
      "config": [fastIntegration, slowIntegration],
      "configForCounter": fastIntegration
    },
    {
      "remoteChain": "bsc-testnet",
      "config": [fastIntegration, slowIntegration],
      "configForCounter": fastIntegration
    },
  ],
  "polygon-mumbai": [
    {
      "remoteChain": "goerli",
      "config": [fastIntegration, slowIntegration, nativeBridgeIntegration],
      "configForCounter": nativeBridgeIntegration
    },
    {
      "remoteChain": "arbitrum-goerli",
      "config": [fastIntegration, slowIntegration],
      "configForCounter": fastIntegration
    },
    {
      "remoteChain": "optimism-goerli",
      "config": [fastIntegration, slowIntegration],
      "configForCounter": fastIntegration
    },
    {
      "remoteChain": "bsc-testnet",
      "config": [fastIntegration, slowIntegration],
      "configForCounter": fastIntegration
    },
  ],
  "bsc-testnet": [
    {
      "remoteChain": "goerli",
      "config": [fastIntegration, slowIntegration],
      "configForCounter": fastIntegration
    },
    {
      "remoteChain": "arbitrum-goerli",
      "config": [fastIntegration, slowIntegration],
      "configForCounter": fastIntegration
    },
    {
      "remoteChain": "optimism-goerli",
      "config": [fastIntegration, slowIntegration],
      "configForCounter": fastIntegration
    },
    {
      "remoteChain": "polygon-mumbai",
      "config": [fastIntegration, slowIntegration],
      "configForCounter": fastIntegration
    },
  ],
  "polygon-mainnet": [
    {
      "remoteChain": "bsc",
      "config": [fastIntegration, slowIntegration],
      "configForCounter": fastIntegration
    },
  ],
  bsc: [
    {
      "remoteChain": "polygon-mainnet",
      "config": [fastIntegration, slowIntegration],
      "configForCounter": fastIntegration
    },
  ]
}