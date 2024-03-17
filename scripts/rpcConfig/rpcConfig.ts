import {
  ChainSlug,
  getAddresses,
  Integrations,
  DeploymentMode,
  S3Config,
  ChainSlugToId,
  TestnetIds,
  MainnetIds,
  getAllAddresses,
} from "../../src";

import dotenv from "dotenv";
dotenv.config();
const deploymentMode = process.env.DEPLOYMENT_MODE as DeploymentMode;
const addresses = getAllAddresses(deploymentMode);

const checkEnvVar = (envVar: string) => {
  let value = process.env[envVar];
  if (!value) {
    throw new Error(`Missing environment variable ${envVar}`);
  }
  return value;
};

const getBlockNumber = (
  deploymentMode: DeploymentMode,
  chainSlug: ChainSlug
) => {
  try {
    const addresses = getAddresses(chainSlug, deploymentMode);
    return addresses.startBlock ?? 1;
  } catch (error) {
    return 1;
  }
};

const getSiblings = (
  deploymentMode: DeploymentMode,
  chainSlug: ChainSlug
): ChainSlug[] => {
  try {
    const integrations: Integrations = getAddresses(
      chainSlug,
      deploymentMode
    ).integrations;
    if (!integrations) return [] as ChainSlug[];

    return Object.keys(integrations).map(
      (chainSlug) => parseInt(chainSlug) as ChainSlug
    );
  } catch (error) {
    return [] as ChainSlug[];
  }
};

const rpcs = {
  [ChainSlug.AEVO]: checkEnvVar("AEVO_RPC"),
  [ChainSlug.ARBITRUM]: checkEnvVar("ARBITRUM_RPC"),
  [ChainSlug.LYRA]: checkEnvVar("LYRA_RPC"),
  [ChainSlug.OPTIMISM]: checkEnvVar("OPTIMISM_RPC"),
  [ChainSlug.BSC]: checkEnvVar("BSC_RPC"),
  [ChainSlug.POLYGON_MAINNET]: checkEnvVar("POLYGON_RPC"),
  [ChainSlug.MAINNET]: checkEnvVar("ETHEREUM_RPC"),
  [ChainSlug.PARALLEL]: checkEnvVar("PARALLEL_RPC"),
  [ChainSlug.HOOK]: checkEnvVar("HOOK_RPC"),
  [ChainSlug.MANTLE]: checkEnvVar("MANTLE_RPC"),
  [ChainSlug.REYA]: checkEnvVar("REYA_RPC"),

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
  [ChainSlug.SX_NETWORK]: checkEnvVar("SX_NETWORK_RPC"),
  [ChainSlug.MODE_TESTNET]: checkEnvVar("MODE_TESTNET_RPC"),
  [ChainSlug.VICTION_TESTNET]: checkEnvVar("VICTION_TESTNET_RPC"),
  [ChainSlug.BASE]: checkEnvVar("BASE_RPC"),
  [ChainSlug.MODE]: checkEnvVar("MODE_RPC"),
  [ChainSlug.ANCIENT8_TESTNET]: checkEnvVar("ANCIENT8_TESTNET_RPC"),
  [ChainSlug.ANCIENT8_TESTNET2]: checkEnvVar("ANCIENT8_TESTNET2_RPC"),
  [ChainSlug.HOOK_TESTNET]: checkEnvVar("HOOK_TESTNET_RPC"),
  [ChainSlug.REYA_CRONOS]: checkEnvVar("REYA_CRONOS_RPC"),
  [ChainSlug.CDK_TESTNET]: checkEnvVar("CDK_TESTNET_RPC"),
};

const devConfig: S3Config = {
  chains: {
    [ChainSlug.ARBITRUM_SEPOLIA]: {
      rpc: rpcs[ChainSlug.ARBITRUM_SEPOLIA],
      blockNumber: 1430261,
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.DEV, ChainSlug.ARBITRUM_SEPOLIA),
    },
    [ChainSlug.OPTIMISM_SEPOLIA]: {
      rpc: rpcs[ChainSlug.OPTIMISM_SEPOLIA],
      blockNumber: 4475713,
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.DEV, ChainSlug.OPTIMISM_SEPOLIA),
    },
    [ChainSlug.SEPOLIA]: {
      rpc: rpcs[ChainSlug.SEPOLIA],
      blockNumber: 4751027,
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.DEV, ChainSlug.SEPOLIA),
    },
    [ChainSlug.POLYGON_MUMBAI]: {
      rpc: rpcs[ChainSlug.POLYGON_MUMBAI],
      blockNumber: 42750896,
      confirmations: 5,
      siblings: getSiblings(DeploymentMode.DEV, ChainSlug.POLYGON_MUMBAI),
    },
  },
  batcherSupportedChainSlugs: [
    ChainSlug.ARBITRUM_SEPOLIA,
    ChainSlug.OPTIMISM_SEPOLIA,
    ChainSlug.SEPOLIA,
    ChainSlug.POLYGON_MUMBAI,
  ],
  watcherSupportedChainSlugs: [
    ChainSlug.ARBITRUM_SEPOLIA,
    ChainSlug.OPTIMISM_SEPOLIA,
    ChainSlug.SEPOLIA,
    ChainSlug.POLYGON_MUMBAI,
  ],
  nativeSupportedChainSlugs: [
    ChainSlug.ARBITRUM_SEPOLIA,
    ChainSlug.OPTIMISM_SEPOLIA,
    ChainSlug.SEPOLIA,
    ChainSlug.POLYGON_MUMBAI,
  ],
  testnetIds: TestnetIds,
  mainnetIds: MainnetIds,
  addresses,
  chainSlugToId: ChainSlugToId,
};

const devConfigPublic = {
  addresses,
  chainSlugToId: ChainSlugToId,
};
const prodConfig: S3Config = {
  chains: {
    [ChainSlug.AEVO]: {
      rpc: rpcs[ChainSlug.AEVO],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.AEVO),
      confirmations: 2,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.AEVO),
    },
    [ChainSlug.ARBITRUM]: {
      rpc: rpcs[ChainSlug.ARBITRUM],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.ARBITRUM),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.ARBITRUM),
    },
    [ChainSlug.LYRA]: {
      rpc: rpcs[ChainSlug.LYRA],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.LYRA),
      confirmations: 2,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.LYRA),
    },
    [ChainSlug.OPTIMISM]: {
      rpc: rpcs[ChainSlug.OPTIMISM],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.OPTIMISM),
      confirmations: 15,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.OPTIMISM),
    },
    [ChainSlug.BSC]: {
      rpc: rpcs[ChainSlug.BSC],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.BSC),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.BSC),
    },
    [ChainSlug.POLYGON_MAINNET]: {
      rpc: rpcs[ChainSlug.POLYGON_MAINNET],
      blockNumber: getBlockNumber(
        DeploymentMode.PROD,
        ChainSlug.POLYGON_MAINNET
      ),
      confirmations: 256,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.POLYGON_MAINNET),
    },
    [ChainSlug.MAINNET]: {
      rpc: rpcs[ChainSlug.MAINNET],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.MAINNET),
      confirmations: 18,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.MAINNET),
    },
    [ChainSlug.BASE]: {
      rpc: rpcs[ChainSlug.BASE],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.BASE),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.BASE),
    },
    [ChainSlug.MODE]: {
      rpc: rpcs[ChainSlug.MODE],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.MODE),
      confirmations: 2,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.MODE),
    },

    [ChainSlug.ARBITRUM_GOERLI]: {
      rpc: rpcs[ChainSlug.ARBITRUM_GOERLI],
      blockNumber: getBlockNumber(
        DeploymentMode.PROD,
        ChainSlug.ARBITRUM_GOERLI
      ),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.ARBITRUM_GOERLI),
    },
    [ChainSlug.AEVO_TESTNET]: {
      rpc: rpcs[ChainSlug.AEVO_TESTNET],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.AEVO_TESTNET),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.AEVO_TESTNET),
    },
    [ChainSlug.LYRA_TESTNET]: {
      rpc: rpcs[ChainSlug.LYRA_TESTNET],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.LYRA_TESTNET),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.LYRA_TESTNET),
    },
    [ChainSlug.OPTIMISM_GOERLI]: {
      rpc: rpcs[ChainSlug.OPTIMISM_GOERLI],
      blockNumber: getBlockNumber(
        DeploymentMode.PROD,
        ChainSlug.OPTIMISM_GOERLI
      ),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.OPTIMISM_GOERLI),
    },
    [ChainSlug.BSC_TESTNET]: {
      rpc: rpcs[ChainSlug.BSC_TESTNET],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.BSC_TESTNET),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.BSC_TESTNET),
    },
    [ChainSlug.GOERLI]: {
      rpc: rpcs[ChainSlug.GOERLI],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.GOERLI),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.GOERLI),
    },
    [ChainSlug.XAI_TESTNET]: {
      rpc: rpcs[ChainSlug.XAI_TESTNET],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.XAI_TESTNET),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.XAI_TESTNET),
    },
    [ChainSlug.SX_NETWORK_TESTNET]: {
      rpc: rpcs[ChainSlug.SX_NETWORK_TESTNET],
      blockNumber: getBlockNumber(
        DeploymentMode.PROD,
        ChainSlug.SX_NETWORK_TESTNET
      ),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.SX_NETWORK_TESTNET),
    },
    [ChainSlug.SX_NETWORK]: {
      rpc: rpcs[ChainSlug.SX_NETWORK],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.SX_NETWORK),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.SX_NETWORK),
    },
    [ChainSlug.MODE_TESTNET]: {
      rpc: rpcs[ChainSlug.MODE_TESTNET],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.MODE_TESTNET),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.MODE_TESTNET),
    },
    [ChainSlug.VICTION_TESTNET]: {
      rpc: rpcs[ChainSlug.VICTION_TESTNET],
      blockNumber: getBlockNumber(
        DeploymentMode.PROD,
        ChainSlug.VICTION_TESTNET
      ),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.VICTION_TESTNET),
    },
    [ChainSlug.CDK_TESTNET]: {
      rpc: rpcs[ChainSlug.CDK_TESTNET],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.CDK_TESTNET),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.CDK_TESTNET),
    },
    [ChainSlug.ARBITRUM_SEPOLIA]: {
      rpc: rpcs[ChainSlug.ARBITRUM_SEPOLIA],
      blockNumber: getBlockNumber(
        DeploymentMode.PROD,
        ChainSlug.ARBITRUM_SEPOLIA
      ),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.ARBITRUM_SEPOLIA),
    },
    [ChainSlug.OPTIMISM_SEPOLIA]: {
      rpc: rpcs[ChainSlug.OPTIMISM_SEPOLIA],
      blockNumber: getBlockNumber(
        DeploymentMode.PROD,
        ChainSlug.OPTIMISM_SEPOLIA
      ),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.OPTIMISM_SEPOLIA),
    },
    [ChainSlug.SEPOLIA]: {
      rpc: rpcs[ChainSlug.SEPOLIA],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.SEPOLIA),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.SEPOLIA),
    },
    [ChainSlug.POLYGON_MUMBAI]: {
      rpc: rpcs[ChainSlug.POLYGON_MUMBAI],
      blockNumber: getBlockNumber(
        DeploymentMode.PROD,
        ChainSlug.POLYGON_MUMBAI
      ),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.POLYGON_MUMBAI),
    },
    [ChainSlug.ANCIENT8_TESTNET]: {
      rpc: rpcs[ChainSlug.ANCIENT8_TESTNET],
      blockNumber: getBlockNumber(
        DeploymentMode.PROD,
        ChainSlug.ANCIENT8_TESTNET
      ),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.ANCIENT8_TESTNET),
    },
    [ChainSlug.ANCIENT8_TESTNET2]: {
      rpc: rpcs[ChainSlug.ANCIENT8_TESTNET2],
      blockNumber: getBlockNumber(
        DeploymentMode.PROD,
        ChainSlug.ANCIENT8_TESTNET2
      ),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.ANCIENT8_TESTNET2),
    },
    [ChainSlug.HOOK_TESTNET]: {
      rpc: rpcs[ChainSlug.HOOK_TESTNET],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.HOOK_TESTNET),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.HOOK_TESTNET),
    },
    [ChainSlug.HOOK]: {
      rpc: rpcs[ChainSlug.HOOK],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.HOOK),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.HOOK),
    },
    [ChainSlug.PARALLEL]: {
      rpc: rpcs[ChainSlug.PARALLEL],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.PARALLEL),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.PARALLEL),
    },
    [ChainSlug.MANTLE]: {
      rpc: rpcs[ChainSlug.MANTLE],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.MANTLE),
      confirmations: 1,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.MANTLE),
    },
    [ChainSlug.REYA_CRONOS]: {
      rpc: rpcs[ChainSlug.REYA_CRONOS],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.REYA_CRONOS),
      confirmations: 0,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.REYA_CRONOS),
    },
    [ChainSlug.REYA]: {
      rpc: rpcs[ChainSlug.REYA],
      blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.REYA),
      confirmations: 0,
      siblings: getSiblings(DeploymentMode.PROD, ChainSlug.REYA),
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
    ChainSlug.PARALLEL,
    ChainSlug.MANTLE,
    ChainSlug.HOOK,
    ChainSlug.REYA,
    ChainSlug.SX_NETWORK,

    ChainSlug.AEVO_TESTNET,
    // ChainSlug.ARBITRUM_GOERLI,
    // ChainSlug.OPTIMISM_GOERLI,
    // ChainSlug.GOERLI,
    ChainSlug.SEPOLIA,
    ChainSlug.POLYGON_MUMBAI,
    // ChainSlug.BSC_TESTNET,
    ChainSlug.LYRA_TESTNET,
    ChainSlug.SX_NETWORK_TESTNET,
    ChainSlug.ARBITRUM_SEPOLIA,
    ChainSlug.OPTIMISM_SEPOLIA,
    ChainSlug.MODE_TESTNET,
    // ChainSlug.VICTION_TESTNET,
    ChainSlug.BASE,
    ChainSlug.MODE,
    // ChainSlug.ANCIENT8_TESTNET,
    ChainSlug.ANCIENT8_TESTNET2,
    ChainSlug.HOOK_TESTNET,
    ChainSlug.REYA_CRONOS,
  ],
  watcherSupportedChainSlugs: [
    ChainSlug.AEVO,
    ChainSlug.ARBITRUM,
    ChainSlug.OPTIMISM,
    ChainSlug.BSC,
    ChainSlug.POLYGON_MAINNET,
    ChainSlug.LYRA,
    ChainSlug.MAINNET,
    ChainSlug.PARALLEL,
    ChainSlug.MANTLE,
    ChainSlug.HOOK,
    ChainSlug.REYA,
    ChainSlug.SX_NETWORK,

    ChainSlug.AEVO_TESTNET,
    // ChainSlug.ARBITRUM_GOERLI,
    // ChainSlug.OPTIMISM_GOERLI,
    // ChainSlug.GOERLI,
    ChainSlug.SEPOLIA,
    ChainSlug.POLYGON_MUMBAI,
    // ChainSlug.BSC_TESTNET,
    ChainSlug.LYRA_TESTNET,
    ChainSlug.SX_NETWORK_TESTNET,
    ChainSlug.ARBITRUM_SEPOLIA,
    ChainSlug.OPTIMISM_SEPOLIA,
    ChainSlug.MODE_TESTNET,
    // ChainSlug.VICTION_TESTNET,
    ChainSlug.BASE,
    ChainSlug.MODE,
    // ChainSlug.ANCIENT8_TESTNET,
    ChainSlug.ANCIENT8_TESTNET2,
    ChainSlug.HOOK_TESTNET,
    ChainSlug.REYA_CRONOS,
  ],
  nativeSupportedChainSlugs: [
    ChainSlug.ARBITRUM,
    ChainSlug.OPTIMISM,
    ChainSlug.POLYGON_MAINNET,
    ChainSlug.LYRA,
    ChainSlug.MAINNET,
    // ChainSlug.ARBITRUM_GOERLI,
    // ChainSlug.OPTIMISM_GOERLI,
    // ChainSlug.GOERLI,
    ChainSlug.SEPOLIA,
    ChainSlug.POLYGON_MUMBAI,
    ChainSlug.LYRA_TESTNET,
    ChainSlug.ARBITRUM_SEPOLIA,
    ChainSlug.OPTIMISM_SEPOLIA,
  ],
  testnetIds: TestnetIds,
  mainnetIds: MainnetIds,
  addresses,
  chainSlugToId: ChainSlugToId,
};

const prodConfigPublic = {
  addresses,
  chainSlugToId: ChainSlugToId,
};
export const config = deploymentMode === "prod" ? prodConfig : devConfig;
export const publicConfig =
  deploymentMode === "prod" ? prodConfigPublic : devConfigPublic;
