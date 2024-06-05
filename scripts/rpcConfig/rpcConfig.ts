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
  S3ChainConfig,
} from "../../src";
import {
  confirmations,
  explorers,
  icons,
  batcherSupportedChainSlugs,
  prodFeesUpdaterSupportedChainSlugs,
  rpcs,
  version,
} from "./constants";
import { getChainTxData } from "./txdata-builder/generate-calldata";

import dotenv from "dotenv";
dotenv.config();

export const deploymentMode = process.env.DEPLOYMENT_MODE as DeploymentMode;
const addresses = getAllAddresses(deploymentMode);

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

const getChainData = async (
  chainSlug: ChainSlug,
  txData: TxData
): Promise<S3ChainConfig> => {
  return {
    rpc: rpcs[chainSlug],
    explorer: explorers[chainSlug],
    chainName: chainSlugToHardhatChainName[chainSlug],
    blockNumber: getBlockNumber(deploymentMode, chainSlug),
    siblings: getSiblings(deploymentMode, chainSlug),
    chainTxData: await getChainTxData(chainSlug, txData),
    nativeToken: getCurrency(chainSlug),
    chainType: getChainType(chainSlug),
    confirmations: confirmations[chainSlug],
    icon: icons[chainSlug],
  };
};

const getAllChainData = async (
  chainSlugs: ChainSlug[],
  txData: TxData
): Promise<{
  [chainSlug in ChainSlug]?: S3ChainConfig;
}> => {
  const chains: {
    [chainSlug in ChainSlug]?: S3ChainConfig;
  } = {};
  await Promise.all(
    chainSlugs.map(async (c) => (chains[c] = await getChainData(c, txData)))
  );

  return chains;
};

export const generateDevConfig = async (txData: TxData): Promise<S3Config> => {
  const batcherSupportedChainSlugs = [
    ChainSlug.ARBITRUM_SEPOLIA,
    ChainSlug.OPTIMISM_SEPOLIA,
    ChainSlug.SEPOLIA,
  ];

  return {
    version: `dev-${version[DeploymentMode.DEV]}`,
    chains: await getAllChainData(batcherSupportedChainSlugs, txData),
    batcherSupportedChainSlugs: batcherSupportedChainSlugs,
    watcherSupportedChainSlugs: batcherSupportedChainSlugs,
    nativeSupportedChainSlugs: [],
    feeUpdaterSupportedChainSlugs: batcherSupportedChainSlugs,
    testnetIds: TestnetIds,
    mainnetIds: MainnetIds,
    addresses,
    chainSlugToId: ChainSlugToId,
  };
};

export const generateProdConfig = async (txData: TxData): Promise<S3Config> => {
  return {
    version: `prod-${version[DeploymentMode.PROD]}`,
    chains: await getAllChainData(batcherSupportedChainSlugs, txData),
    batcherSupportedChainSlugs: batcherSupportedChainSlugs,
    watcherSupportedChainSlugs: batcherSupportedChainSlugs,
    nativeSupportedChainSlugs: [
      ChainSlug.ARBITRUM,
      ChainSlug.OPTIMISM,
      ChainSlug.POLYGON_MAINNET,
      ChainSlug.LYRA,
      ChainSlug.MAINNET,
      ChainSlug.GOERLI,
      ChainSlug.SEPOLIA,
      ChainSlug.LYRA_TESTNET,
      ChainSlug.ARBITRUM_SEPOLIA,
      ChainSlug.OPTIMISM_SEPOLIA,
    ],
    feeUpdaterSupportedChainSlugs: prodFeesUpdaterSupportedChainSlugs(),
    testnetIds: TestnetIds,
    mainnetIds: MainnetIds,
    addresses,
    chainSlugToId: ChainSlugToId,
  };
};
