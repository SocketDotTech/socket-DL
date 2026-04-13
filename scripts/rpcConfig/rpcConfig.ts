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
  zkStackChain,
} from "../../src";
import { getSiblings } from "../common";
import { chainOverrides } from "../constants/overrides";
import {
  batcherSupportedChainSlugs,
  disabledDFFeeChains,
  explorers,
  getEventBlockRange,
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
  } catch (error) {
    return [] as ChainSlug[];
  }
  return chains;
};

/**
 * Parses chain surcharge configuration from environment variable
 * Format: "chainSlug:usdAmount,chainSlug:usdAmount,..."
 * Example: "1324967486:2,1:1.5,42161:1"
 *
 * @returns Object mapping chain slug (as string) to USD surcharge amount
 */
const parseChainSurchargeFromEnv = (): { [chainSlug: string]: number } => {
  const envVar = process.env.CHAIN_SURCHARGE_USD;

  // If not set, return empty object
  if (!envVar || envVar.trim() === "") {
    return {};
  }

  const surchargeMap: { [chainSlug: string]: number } = {};

  try {
    // Split by comma to get individual chain:amount pairs
    const pairs = envVar
      .split(",")
      .map((p) => p.trim())
      .filter((p) => p.length > 0);

    for (const pair of pairs) {
      const [chainSlugStr, amountStr] = pair.split(":").map((s) => s.trim());

      // Validate format
      if (!chainSlugStr || !amountStr) {
        console.warn(
          `Invalid chain surcharge pair: "${pair}". Expected format: "chainSlug:amount"`
        );
        continue;
      }

      // Validate chain slug is a valid number
      const chainSlug = parseInt(chainSlugStr);
      if (isNaN(chainSlug) || chainSlug <= 0) {
        console.warn(
          `Invalid chain slug: "${chainSlugStr}". Must be a positive integer.`
        );
        continue;
      }

      // Validate amount is a valid positive number
      const amount = parseFloat(amountStr);
      if (isNaN(amount) || amount < 0) {
        console.warn(
          `Invalid surcharge amount: "${amountStr}". Must be a non-negative number.`
        );
        continue;
      }

      // Store with chain slug as string (JSON key requirement)
      surchargeMap[chainSlugStr] = amount;
    }

    console.log(
      `Parsed chain surcharge config: ${
        Object.keys(surchargeMap).length
      } chains with surcharges`
    );
    return surchargeMap;
  } catch (error) {
    console.error(`Error parsing CHAIN_SURCHARGE_USD: ${error}`);
    return {};
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
    return ChainType.zkStackChain;
  } else if (zkStackChain.includes(chainSlug)) {
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
    chainTxData: getChainTxData(chainSlug, txData),
    nativeToken: getCurrency(chainSlug),
    chainType: getChainType(chainSlug),
    reSyncInterval: getReSyncInterval(chainSlug),
    confirmations: getReSyncInterval(chainSlug),
    eventBlockRange: getEventBlockRange(chainSlug),
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
    chainSurchargeUsdBySlug: parseChainSurchargeFromEnv(),
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
    chainSurchargeUsdBySlug: parseChainSurchargeFromEnv(),
  };
};
