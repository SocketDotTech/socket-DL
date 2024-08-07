import {
  arbChains,
  arbL3Chains,
  ChainSlug,
  chainSlugToHardhatChainName,
  ChainSlugToId,
  ChainSocketAddresses,
  ChainType,
  DeploymentAddresses,
  DeploymentMode,
  getAddresses,
  getAllAddresses,
  getCurrency,
  MainnetIds,
  opStackL2Chain,
  polygonCDKChains,
  S3ChainConfig,
  S3Config,
  TestnetIds,
  TxData,
} from "../../src";
import { getSiblings } from "../common";
import { chainOverrides } from "../constants/overrides";
import {
  batcherSupportedChainSlugs,
  disabledDFFeeChains,
  explorers,
  getDefaultFinalityBucket,
  getFinality,
  getReSyncInterval,
  icons,
  rpcs,
  version,
} from "./constants";
import { feesUpdaterSupportedChainSlugs } from "./constants/feesUpdaterChainSlugs";
import { getChainTxData } from "./txdata-builder/generate-calldata";

import dotenv from "dotenv";
dotenv.config();

export const deploymentMode = process.env.DEPLOYMENT_MODE as DeploymentMode;
const addresses: DeploymentAddresses = getAllAddresses(deploymentMode);

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

const getOldEMVersionChainSlugs = (): ChainSlug[] => {
  let chains: ChainSlug[] = [];
  try {
    if (chains.length !== 0) return chains;
    Object.keys(addresses).map((chain) => {
      const chainAddress: ChainSocketAddresses = addresses[chain];
      if (!chainAddress.ExecutionManagerDF)
        chains.push(parseInt(chain) as ChainSlug);
    });

    console.log(chains);
  } catch (error) {
    return [] as ChainSlug[];
  }
  return chains;
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
    chainName: chainSlugToHardhatChainName[chainSlug].toString(),
    blockNumber: getBlockNumber(deploymentMode, chainSlug),
    siblings: getSiblings(deploymentMode, chainSlug),
    chainTxData: await getChainTxData(chainSlug, txData),
    nativeToken: getCurrency(chainSlug),
    chainType: getChainType(chainSlug),
    reSyncInterval: getReSyncInterval(chainSlug),
    confirmations: getReSyncInterval(chainSlug),
    finalityInfo: getFinality(chainSlug),
    defaultFinalityBucket: getDefaultFinalityBucket(chainSlug),
    icon: icons[chainSlug],
    overrides: chainOverrides[chainSlug],
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
  const batcherSupportedChainSlugs = feesUpdaterSupportedChainSlugs();

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
    oldEMVersionChainSlugs: getOldEMVersionChainSlugs(),
    disabledDFFeeChains,
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
    feeUpdaterSupportedChainSlugs: feesUpdaterSupportedChainSlugs(),
    testnetIds: TestnetIds,
    mainnetIds: MainnetIds,
    addresses,
    chainSlugToId: ChainSlugToId,
    oldEMVersionChainSlugs: getOldEMVersionChainSlugs(),
    disabledDFFeeChains,
  };
};
