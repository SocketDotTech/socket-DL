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
  ChainType,
  TxData,
  chainSlugToHardhatChainName,
  getCurrency,
  opStackL2Chain,
  arbChains,
  arbL3Chains,
  polygonCDKChains,
} from "../../src";
import { getChainTxData } from "./txdata-builder/generate-calldata";

import dotenv from "dotenv";
dotenv.config();
export const deploymentMode = process.env.DEPLOYMENT_MODE as DeploymentMode;
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

const getChainType = (chainSlug: ChainSlug) => {
  if (opStackL2Chain.includes(chainSlug)) {
    return ChainType.opStackL2Chain;
  } else if (arbChains.includes(chainSlug)) {
    return ChainType.arbChain;
  } else if (arbL3Chains.includes(chainSlug)) {
    return ChainType.arbL3Chain;
  } else if (polygonCDKChains.includes(chainSlug)) {
    return ChainType.polygonCDKChain;
  } else return ChainType.default;
};

const getChainData = async (chainSlug: ChainSlug, txData: TxData) => {
  return {
    rpc: rpcs[chainSlug],
    chainName: chainSlugToHardhatChainName[chainSlug],
    blockNumber: getBlockNumber(deploymentMode, chainSlug),
    siblings: getSiblings(deploymentMode, chainSlug),
    chainTxData: await getChainTxData(chainSlug, txData),
    nativeToken: getCurrency(chainSlug),
    chainType: getChainType(chainSlug),
  };
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
  [ChainSlug.SYNDR_SEPOLIA_L3]: checkEnvVar("SYNDR_SEPOLIA_L3_RPC"),
  [ChainSlug.POLYNOMIAL_TESTNET]: checkEnvVar("POLYNOMIAL_TESTNET_RPC"),
  [ChainSlug.CDK_TESTNET]: checkEnvVar("CDK_TESTNET_RPC"),
};

export const generateDevConfig = async (txData: TxData): Promise<S3Config> => {
  const config = {
    version: "prod-1.0.2",
    chains: {
      [ChainSlug.ARBITRUM_SEPOLIA]: {
        ...(await getChainData(ChainSlug.ARBITRUM_SEPOLIA, txData)),
        confirmations: 1,
      },
      [ChainSlug.OPTIMISM_SEPOLIA]: {
        ...(await getChainData(ChainSlug.OPTIMISM_SEPOLIA, txData)),
        confirmations: 1,
      },
      [ChainSlug.SEPOLIA]: {
        ...(await getChainData(ChainSlug.SEPOLIA, txData)),
        confirmations: 1,
      },
      [ChainSlug.POLYGON_MUMBAI]: {
        ...(await getChainData(ChainSlug.POLYGON_MUMBAI, txData)),
        confirmations: 5,
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
    feeUpdaterSupportedChainSlugs: [
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

  return config;
};

export const generateProdConfig = async (txData: TxData): Promise<S3Config> => {
  const config = {
    version: "prod-1.0.2",
    chains: {
      [ChainSlug.AEVO]: {
        ...(await getChainData(ChainSlug.AEVO, txData)),
        confirmations: 2,
      },
      [ChainSlug.ARBITRUM]: {
        ...(await getChainData(ChainSlug.ARBITRUM, txData)),
        confirmations: 1,
      },
      [ChainSlug.LYRA]: {
        ...(await getChainData(ChainSlug.LYRA, txData)),
        confirmations: 2,
      },
      [ChainSlug.OPTIMISM]: {
        ...(await getChainData(ChainSlug.OPTIMISM, txData)),
        confirmations: 15,
      },
      [ChainSlug.BSC]: {
        ...(await getChainData(ChainSlug.BSC, txData)),
        confirmations: 1,
      },
      [ChainSlug.POLYGON_MAINNET]: {
        confirmations: 256,
        ...(await getChainData(ChainSlug.POLYGON_MAINNET, txData)),
      },
      [ChainSlug.MAINNET]: {
        confirmations: 18,
        ...(await getChainData(ChainSlug.MAINNET, txData)),
      },
      [ChainSlug.BASE]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.BASE, txData)),
      },
      [ChainSlug.MODE]: {
        confirmations: 2,
        ...(await getChainData(ChainSlug.MODE, txData)),
      },
      [ChainSlug.ARBITRUM_GOERLI]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.ARBITRUM_GOERLI, txData)),
      },
      [ChainSlug.AEVO_TESTNET]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.AEVO_TESTNET, txData)),
      },
      [ChainSlug.LYRA_TESTNET]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.LYRA_TESTNET, txData)),
      },
      [ChainSlug.OPTIMISM_GOERLI]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.OPTIMISM_GOERLI, txData)),
      },
      [ChainSlug.BSC_TESTNET]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.BSC_TESTNET, txData)),
      },
      [ChainSlug.GOERLI]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.GOERLI, txData)),
      },
      [ChainSlug.XAI_TESTNET]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.XAI_TESTNET, txData)),
      },
      [ChainSlug.SX_NETWORK_TESTNET]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.SX_NETWORK_TESTNET, txData)),
      },
      [ChainSlug.SX_NETWORK]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.SX_NETWORK, txData)),
      },
      [ChainSlug.MODE_TESTNET]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.MODE_TESTNET, txData)),
      },
      [ChainSlug.VICTION_TESTNET]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.VICTION_TESTNET, txData)),
      },
      [ChainSlug.CDK_TESTNET]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.CDK_TESTNET, txData)),
      },
      [ChainSlug.ARBITRUM_SEPOLIA]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.ARBITRUM_SEPOLIA, txData)),
      },
      [ChainSlug.OPTIMISM_SEPOLIA]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.OPTIMISM_SEPOLIA, txData)),
      },
      [ChainSlug.SEPOLIA]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.SEPOLIA, txData)),
      },
      [ChainSlug.POLYGON_MUMBAI]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.POLYGON_MUMBAI, txData)),
      },
      [ChainSlug.ANCIENT8_TESTNET]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.ANCIENT8_TESTNET, txData)),
      },
      [ChainSlug.ANCIENT8_TESTNET2]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.ANCIENT8_TESTNET2, txData)),
      },
      [ChainSlug.HOOK_TESTNET]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.HOOK_TESTNET, txData)),
      },
      [ChainSlug.HOOK]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.HOOK, txData)),
      },
      [ChainSlug.PARALLEL]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.PARALLEL, txData)),
      },
      [ChainSlug.MANTLE]: {
        confirmations: 1,
        ...(await getChainData(ChainSlug.MANTLE, txData)),
      },
      [ChainSlug.REYA_CRONOS]: {
        ...(await getChainData(ChainSlug.REYA_CRONOS, txData)),
        confirmations: 0,
      },
      [ChainSlug.REYA]: {
        ...(await getChainData(ChainSlug.REYA, txData)),
        confirmations: 0,
      },
      [ChainSlug.SYNDR_SEPOLIA_L3]: {
        ...(await getChainData(ChainSlug.SYNDR_SEPOLIA_L3, txData)),
        confirmations: 1,
      },
      [ChainSlug.POLYNOMIAL_TESTNET]: {
        ...(await getChainData(ChainSlug.POLYNOMIAL_TESTNET, txData)),
        confirmations: 1,
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
      // ChainSlug.PARALLEL,
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
      ChainSlug.SYNDR_SEPOLIA_L3,
      ChainSlug.POLYNOMIAL_TESTNET,
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
      ChainSlug.SYNDR_SEPOLIA_L3,
      ChainSlug.POLYNOMIAL_TESTNET,
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
    feeUpdaterSupportedChainSlugs: [
      ChainSlug.AEVO,
      ChainSlug.ARBITRUM,
      ChainSlug.OPTIMISM,
      ChainSlug.BSC,
      ChainSlug.POLYGON_MAINNET,
      ChainSlug.LYRA,
      ChainSlug.MAINNET,
      // ChainSlug.PARALLEL,
      ChainSlug.MANTLE,
      ChainSlug.HOOK,
      ChainSlug.REYA,
      ChainSlug.SX_NETWORK,

      // ChainSlug.AEVO_TESTNET,
      // ChainSlug.ARBITRUM_GOERLI,
      // ChainSlug.OPTIMISM_GOERLI,
      // ChainSlug.GOERLI,
      // ChainSlug.SEPOLIA,
      // ChainSlug.POLYGON_MUMBAI,
      // ChainSlug.BSC_TESTNET,
      // ChainSlug.LYRA_TESTNET,
      // ChainSlug.SX_NETWORK_TESTNET,
      // ChainSlug.ARBITRUM_SEPOLIA,
      // ChainSlug.OPTIMISM_SEPOLIA,
      // ChainSlug.MODE_TESTNET,
      // ChainSlug.VICTION_TESTNET,
      ChainSlug.BASE,
      ChainSlug.MODE,
      // ChainSlug.ANCIENT8_TESTNET,
      // ChainSlug.ANCIENT8_TESTNET2,
      // ChainSlug.HOOK_TESTNET,
      // ChainSlug.REYA_CRONOS,
      // ChainSlug.SYNDR_SEPOLIA_L3,
      ChainSlug.POLYNOMIAL_TESTNET,
    ],
    testnetIds: TestnetIds,
    mainnetIds: MainnetIds,
    addresses,
    chainSlugToId: ChainSlugToId,
  };

  return config;
};
