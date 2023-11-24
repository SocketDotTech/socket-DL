import { ChainSlug } from "../../src";
import { DeploymentMode } from "../../src";

import dotenv from "dotenv";
dotenv.config();
const deploymentMode = process.env.DEPLOYMENT_MODE as DeploymentMode;

const checkEnvVar = (envVar: string) => {
  let value = process.env[envVar];
  if (!value) {
    throw new Error(`Missing environment variable ${envVar}`);
  }
  return value;
};

const rpcs = {
  [ChainSlug.AEVO]: checkEnvVar("AEVO_RPC"),
  [ChainSlug.ARBITRUM]: checkEnvVar("ARBITRUM_RPC"),
  [ChainSlug.LYRA]: checkEnvVar("LYRA_RPC"),
  [ChainSlug.OPTIMISM]: checkEnvVar("OPTIMISM_RPC"),
  [ChainSlug.BSC]: checkEnvVar("BSC_RPC"),
  [ChainSlug.POLYGON_MAINNET]: checkEnvVar("POLYGON_RPC"),
  [ChainSlug.MAINNET]: checkEnvVar("ETHEREUM_RPC"),

  [ChainSlug.ARBITRUM_SEPOLIA]: checkEnvVar("ARBITRUM_SEPOLIA_RPC"),
  [ChainSlug.OPTIMISM_SEPOLIA]: checkEnvVar("OPTIMISM_SEPOLIA_RPC"),
  [ChainSlug.SEPOLIA]: checkEnvVar("SEPOLIA_RPC"),
  [ChainSlug.POLYGON_MUMBAI]: checkEnvVar("POLYGON_MUMBAI_RPC"),
  [ChainSlug.ARBITRUM_GOERLI]: checkEnvVar("ARB_GOERLI_RPC"),
  [ChainSlug.AEVO_TESTNET]: checkEnvVar("AEVO_TESTNET_RPC"),
  [ChainSlug.LYRA_TESTNET]: checkEnvVar("LYRA_TESTNET_RPC"),
  [ChainSlug.OPTIMISM_GOERLI]: checkEnvVar("OPTIMISM_GOERLI_RPC"),
  [ChainSlug.BSC_TESTNET]: checkEnvVar("BSC_TESTNET_RPC"),
  [ChainSlug.GOERLI]: checkEnvVar("GOERLI_RPC"),
  [ChainSlug.XAI_TESTNET]: checkEnvVar("XAI_TESTNET_RPC"),
  [ChainSlug.SX_NETWORK_TESTNET]: checkEnvVar("SX_NETWORK_TESTNET_RPC"),
  [ChainSlug.CDK_TESTNET]: checkEnvVar("CDK_TESTNET_RPC"),
};

const devConfig = {
  chains: {
    [ChainSlug.ARBITRUM_SEPOLIA]: {
      rpc: rpcs[ChainSlug.ARBITRUM_SEPOLIA],
      // blockNumber:,
    },
    [ChainSlug.OPTIMISM_SEPOLIA]: {
      rpc: rpcs[ChainSlug.OPTIMISM_SEPOLIA],
      // blockNumber:,
    },
    [ChainSlug.SEPOLIA]: {
      rpc: rpcs[ChainSlug.SEPOLIA],
      // blockNumber:,
    },
    [ChainSlug.POLYGON_MUMBAI]: {
      rpc: rpcs[ChainSlug.POLYGON_MUMBAI],
      // blockNumber:,
    },
    [ChainSlug.SX_NETWORK_TESTNET]: {
      rpc: rpcs[ChainSlug.SX_NETWORK_TESTNET],
      // blockNumber:,
    },
  },
  batcherSupportedChainSlugs: [
    ChainSlug.ARBITRUM_SEPOLIA,
    ChainSlug.OPTIMISM_SEPOLIA,
    ChainSlug.SEPOLIA,
    ChainSlug.POLYGON_MUMBAI,
    ChainSlug.SX_NETWORK_TESTNET,
  ],
};

const prodConfig = {
  chains: {
    [ChainSlug.AEVO]: {
      rpc: rpcs[ChainSlug.AEVO],
      // blockNumber:,
    },
    [ChainSlug.ARBITRUM]: {
      rpc: rpcs[ChainSlug.ARBITRUM],
      // blockNumber:,
    },
    [ChainSlug.LYRA]: {
      rpc: rpcs[ChainSlug.LYRA],
      // blockNumber:,
    },
    [ChainSlug.OPTIMISM]: {
      rpc: rpcs[ChainSlug.OPTIMISM],
      // blockNumber:,
    },
    [ChainSlug.BSC]: {
      rpc: rpcs[ChainSlug.BSC],
      // blockNumber:,
    },
    [ChainSlug.POLYGON_MAINNET]: {
      rpc: rpcs[ChainSlug.POLYGON_MAINNET],
      // blockNumber:,
    },
    [ChainSlug.MAINNET]: {
      rpc: rpcs[ChainSlug.MAINNET],
      // blockNumber:,
    },
    [ChainSlug.ARBITRUM_GOERLI]: {
      rpc: rpcs[ChainSlug.ARBITRUM_GOERLI],
      // blockNumber:,
    },
    [ChainSlug.AEVO_TESTNET]: {
      rpc: rpcs[ChainSlug.AEVO_TESTNET],
      // blockNumber:,
    },
    [ChainSlug.LYRA_TESTNET]: {
      rpc: rpcs[ChainSlug.LYRA_TESTNET],
      // blockNumber:,
    },
    [ChainSlug.OPTIMISM_GOERLI]: {
      rpc: rpcs[ChainSlug.OPTIMISM_GOERLI],
      // blockNumber:,
    },
    [ChainSlug.BSC_TESTNET]: {
      rpc: rpcs[ChainSlug.BSC_TESTNET],
      // blockNumber:,
    },
    [ChainSlug.GOERLI]: {
      rpc: rpcs[ChainSlug.GOERLI],
      // blockNumber:,
    },
    [ChainSlug.XAI_TESTNET]: {
      rpc: rpcs[ChainSlug.XAI_TESTNET],
      // blockNumber:,
    },
    [ChainSlug.SX_NETWORK_TESTNET]: {
      rpc: rpcs[ChainSlug.SX_NETWORK_TESTNET],
      // blockNumber:,
    },
    [ChainSlug.CDK_TESTNET]: {
      rpc: rpcs[ChainSlug.CDK_TESTNET],
      // blockNumber:,
    },
    [ChainSlug.ARBITRUM_SEPOLIA]: {
      rpc: rpcs[ChainSlug.ARBITRUM_SEPOLIA],
      // blockNumber:,
    },
    [ChainSlug.OPTIMISM_SEPOLIA]: {
      rpc: rpcs[ChainSlug.OPTIMISM_SEPOLIA],
      // blockNumber:,
    },
    [ChainSlug.SEPOLIA]: {
      rpc: rpcs[ChainSlug.SEPOLIA],
      // blockNumber:,
    },
    [ChainSlug.POLYGON_MUMBAI]: {
      rpc: rpcs[ChainSlug.POLYGON_MUMBAI],
      // blockNumber:,
    },
  },
  batcherSupportedChainSlugs: [
    ChainSlug.AEVO,
    ChainSlug.ARBITRUM,
    ChainSlug.OPTIMISM,
    ChainSlug.BSC,
    ChainSlug.POLYGON_MAINNET,
    ChainSlug.LYRA,
    ChainSlug.MAINNET,

    ChainSlug.AEVO_TESTNET,
    ChainSlug.ARBITRUM_GOERLI,
    ChainSlug.OPTIMISM_GOERLI,
    ChainSlug.GOERLI,
    ChainSlug.SEPOLIA,
    ChainSlug.POLYGON_MUMBAI,
    // ChainSlug.BSC_TESTNET,
    ChainSlug.LYRA_TESTNET,
    ChainSlug.XAI_TESTNET,
    ChainSlug.SX_NETWORK_TESTNET,
    ChainSlug.CDK_TESTNET,
    ChainSlug.ARBITRUM_SEPOLIA,
    ChainSlug.OPTIMISM_SEPOLIA,
  ],
};

export const config = deploymentMode === "prod" ? prodConfig : devConfig;
