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
  NativeTokens,
  ChainType,
  HardhatChainName,
  TxData,
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
    version: "dev-1.0.0",
    chains: {
      [ChainSlug.ARBITRUM_SEPOLIA]: {
        rpc: rpcs[ChainSlug.ARBITRUM_SEPOLIA],
        blockNumber: 1430261,
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.DEV, ChainSlug.ARBITRUM_SEPOLIA),
        chainName: HardhatChainName.ARBITRUM_SEPOLIA,
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.ARBITRUM_SEPOLIA, txData),
      },
      [ChainSlug.OPTIMISM_SEPOLIA]: {
        rpc: rpcs[ChainSlug.OPTIMISM_SEPOLIA],
        blockNumber: 4475713,
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.DEV, ChainSlug.OPTIMISM_SEPOLIA),
        chainName: HardhatChainName.OPTIMISM_SEPOLIA,
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.opStackL2Chain,
        chainTxData: await getChainTxData(ChainSlug.OPTIMISM_SEPOLIA, txData),
      },
      [ChainSlug.SEPOLIA]: {
        rpc: rpcs[ChainSlug.SEPOLIA],
        blockNumber: 4751027,
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.DEV, ChainSlug.SEPOLIA),
        chainName: HardhatChainName.SEPOLIA,
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.SEPOLIA, txData),
      },
      [ChainSlug.POLYGON_MUMBAI]: {
        rpc: rpcs[ChainSlug.POLYGON_MUMBAI],
        blockNumber: 42750896,
        confirmations: 5,
        siblings: getSiblings(DeploymentMode.DEV, ChainSlug.POLYGON_MUMBAI),
        chainName: HardhatChainName.POLYGON_MUMBAI,
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.POLYGON_MUMBAI, txData),
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
        rpc: rpcs[ChainSlug.AEVO],
        chainName: HardhatChainName.AEVO,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.AEVO),
        confirmations: 2,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.AEVO),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.opStackL2Chain,
        chainTxData: await getChainTxData(ChainSlug.AEVO, txData),
      },
      [ChainSlug.ARBITRUM]: {
        rpc: rpcs[ChainSlug.ARBITRUM],
        chainName: HardhatChainName.ARBITRUM,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.ARBITRUM),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.ARBITRUM),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.arbChain,
        chainTxData: await getChainTxData(ChainSlug.ARBITRUM, txData),
      },
      [ChainSlug.LYRA]: {
        rpc: rpcs[ChainSlug.LYRA],
        chainName: HardhatChainName.LYRA,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.LYRA),
        confirmations: 2,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.LYRA),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.opStackL2Chain,
        chainTxData: await getChainTxData(ChainSlug.LYRA, txData),
      },
      [ChainSlug.OPTIMISM]: {
        rpc: rpcs[ChainSlug.OPTIMISM],
        chainName: HardhatChainName.OPTIMISM,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.OPTIMISM),
        confirmations: 15,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.OPTIMISM),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.opStackL2Chain,
        chainTxData: await getChainTxData(ChainSlug.OPTIMISM, txData),
      },
      [ChainSlug.BSC]: {
        rpc: rpcs[ChainSlug.BSC],
        chainName: HardhatChainName.BSC,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.BSC),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.BSC),
        nativeToken: NativeTokens.binancecoin,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.BSC, txData),
      },
      [ChainSlug.POLYGON_MAINNET]: {
        rpc: rpcs[ChainSlug.POLYGON_MAINNET],
        chainName: HardhatChainName.POLYGON_MAINNET,
        blockNumber: getBlockNumber(
          DeploymentMode.PROD,
          ChainSlug.POLYGON_MAINNET
        ),
        confirmations: 256,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.POLYGON_MAINNET),
        nativeToken: NativeTokens["matic-network"],
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.POLYGON_MAINNET, txData),
      },
      [ChainSlug.MAINNET]: {
        rpc: rpcs[ChainSlug.MAINNET],
        chainName: HardhatChainName.MAINNET,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.MAINNET),
        confirmations: 18,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.MAINNET),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.MAINNET, txData),
      },
      [ChainSlug.BASE]: {
        rpc: rpcs[ChainSlug.BASE],
        chainName: HardhatChainName.BASE,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.BASE),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.BASE),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.opStackL2Chain,
        chainTxData: await getChainTxData(ChainSlug.BASE, txData),
      },
      [ChainSlug.MODE]: {
        rpc: rpcs[ChainSlug.MODE],
        chainName: HardhatChainName.MODE,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.MODE),
        confirmations: 2,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.MODE),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.opStackL2Chain,
        chainTxData: await getChainTxData(ChainSlug.MODE, txData),
      },

      [ChainSlug.ARBITRUM_GOERLI]: {
        rpc: rpcs[ChainSlug.ARBITRUM_GOERLI],
        chainName: HardhatChainName.ARBITRUM_GOERLI,
        blockNumber: getBlockNumber(
          DeploymentMode.PROD,
          ChainSlug.ARBITRUM_GOERLI
        ),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.ARBITRUM_GOERLI),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.arbChain,
        chainTxData: await getChainTxData(ChainSlug.ARBITRUM_GOERLI, txData),
      },
      [ChainSlug.AEVO_TESTNET]: {
        rpc: rpcs[ChainSlug.AEVO_TESTNET],
        chainName: HardhatChainName.AEVO_TESTNET,
        blockNumber: getBlockNumber(
          DeploymentMode.PROD,
          ChainSlug.AEVO_TESTNET
        ),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.AEVO_TESTNET),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.opStackL2Chain,
        chainTxData: await getChainTxData(ChainSlug.AEVO_TESTNET, txData),
      },
      [ChainSlug.LYRA_TESTNET]: {
        rpc: rpcs[ChainSlug.LYRA_TESTNET],
        chainName: HardhatChainName.LYRA_TESTNET,
        blockNumber: getBlockNumber(
          DeploymentMode.PROD,
          ChainSlug.LYRA_TESTNET
        ),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.LYRA_TESTNET),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.opStackL2Chain,
        chainTxData: await getChainTxData(ChainSlug.LYRA_TESTNET, txData),
      },
      [ChainSlug.OPTIMISM_GOERLI]: {
        rpc: rpcs[ChainSlug.OPTIMISM_GOERLI],
        chainName: HardhatChainName.OPTIMISM_GOERLI,
        blockNumber: getBlockNumber(
          DeploymentMode.PROD,
          ChainSlug.OPTIMISM_GOERLI
        ),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.OPTIMISM_GOERLI),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.opStackL2Chain,
        chainTxData: await getChainTxData(ChainSlug.OPTIMISM_GOERLI, txData),
      },
      [ChainSlug.BSC_TESTNET]: {
        rpc: rpcs[ChainSlug.BSC_TESTNET],
        chainName: HardhatChainName.BSC_TESTNET,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.BSC_TESTNET),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.BSC_TESTNET),
        nativeToken: NativeTokens.binancecoin,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.BSC_TESTNET, txData),
      },
      [ChainSlug.GOERLI]: {
        rpc: rpcs[ChainSlug.GOERLI],
        chainName: HardhatChainName.GOERLI,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.GOERLI),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.GOERLI),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.GOERLI, txData),
      },
      [ChainSlug.XAI_TESTNET]: {
        rpc: rpcs[ChainSlug.XAI_TESTNET],
        chainName: HardhatChainName.XAI_TESTNET,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.XAI_TESTNET),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.XAI_TESTNET),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.polygonCDKChain,
        chainTxData: await getChainTxData(ChainSlug.XAI_TESTNET, txData),
      },
      [ChainSlug.SX_NETWORK_TESTNET]: {
        rpc: rpcs[ChainSlug.SX_NETWORK_TESTNET],
        chainName: HardhatChainName.SX_NETWORK_TESTNET,
        blockNumber: getBlockNumber(
          DeploymentMode.PROD,
          ChainSlug.SX_NETWORK_TESTNET
        ),
        confirmations: 1,
        siblings: getSiblings(
          DeploymentMode.PROD,
          ChainSlug.SX_NETWORK_TESTNET
        ),
        nativeToken: NativeTokens["sx-network-2"],
        chainType: ChainType.arbL3Chain,
        chainTxData: await getChainTxData(ChainSlug.SX_NETWORK_TESTNET, txData),
      },
      [ChainSlug.SX_NETWORK]: {
        rpc: rpcs[ChainSlug.SX_NETWORK],
        chainName: HardhatChainName.SX_NETWORK,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.SX_NETWORK),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.SX_NETWORK),
        nativeToken: NativeTokens["sx-network-2"],
        chainType: ChainType.arbL3Chain,
        chainTxData: await getChainTxData(ChainSlug.SX_NETWORK, txData),
      },
      [ChainSlug.MODE_TESTNET]: {
        rpc: rpcs[ChainSlug.MODE_TESTNET],
        chainName: HardhatChainName.MODE_TESTNET,
        blockNumber: getBlockNumber(
          DeploymentMode.PROD,
          ChainSlug.MODE_TESTNET
        ),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.MODE_TESTNET),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.opStackL2Chain,
        chainTxData: await getChainTxData(ChainSlug.MODE_TESTNET, txData),
      },
      [ChainSlug.VICTION_TESTNET]: {
        rpc: rpcs[ChainSlug.VICTION_TESTNET],
        chainName: HardhatChainName.VICTION_TESTNET,
        blockNumber: getBlockNumber(
          DeploymentMode.PROD,
          ChainSlug.VICTION_TESTNET
        ),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.VICTION_TESTNET),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.VICTION_TESTNET, txData),
      },
      [ChainSlug.CDK_TESTNET]: {
        rpc: rpcs[ChainSlug.CDK_TESTNET],
        chainName: HardhatChainName.CDK_TESTNET,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.CDK_TESTNET),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.CDK_TESTNET),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.CDK_TESTNET, txData),
      },
      [ChainSlug.ARBITRUM_SEPOLIA]: {
        rpc: rpcs[ChainSlug.ARBITRUM_SEPOLIA],
        chainName: HardhatChainName.ARBITRUM_SEPOLIA,
        blockNumber: getBlockNumber(
          DeploymentMode.PROD,
          ChainSlug.ARBITRUM_SEPOLIA
        ),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.ARBITRUM_SEPOLIA),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.arbChain,
        chainTxData: await getChainTxData(ChainSlug.ARBITRUM_SEPOLIA, txData),
      },
      [ChainSlug.OPTIMISM_SEPOLIA]: {
        rpc: rpcs[ChainSlug.OPTIMISM_SEPOLIA],
        chainName: HardhatChainName.OPTIMISM_SEPOLIA,
        blockNumber: getBlockNumber(
          DeploymentMode.PROD,
          ChainSlug.OPTIMISM_SEPOLIA
        ),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.OPTIMISM_SEPOLIA),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.opStackL2Chain,
        chainTxData: await getChainTxData(ChainSlug.OPTIMISM_SEPOLIA, txData),
      },
      [ChainSlug.SEPOLIA]: {
        rpc: rpcs[ChainSlug.SEPOLIA],
        chainName: HardhatChainName.SEPOLIA,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.SEPOLIA),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.SEPOLIA),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.SEPOLIA, txData),
      },
      [ChainSlug.POLYGON_MUMBAI]: {
        rpc: rpcs[ChainSlug.POLYGON_MUMBAI],
        chainName: HardhatChainName.POLYGON_MUMBAI,
        blockNumber: getBlockNumber(
          DeploymentMode.PROD,
          ChainSlug.POLYGON_MUMBAI
        ),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.POLYGON_MUMBAI),
        nativeToken: NativeTokens["matic-network"],
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.POLYGON_MUMBAI, txData),
      },
      [ChainSlug.ANCIENT8_TESTNET]: {
        rpc: rpcs[ChainSlug.ANCIENT8_TESTNET],
        chainName: HardhatChainName.ANCIENT8_TESTNET,
        blockNumber: getBlockNumber(
          DeploymentMode.PROD,
          ChainSlug.ANCIENT8_TESTNET
        ),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.ANCIENT8_TESTNET),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.ANCIENT8_TESTNET, txData),
      },
      [ChainSlug.ANCIENT8_TESTNET2]: {
        rpc: rpcs[ChainSlug.ANCIENT8_TESTNET2],
        chainName: HardhatChainName.ANCIENT8_TESTNET2,
        blockNumber: getBlockNumber(
          DeploymentMode.PROD,
          ChainSlug.ANCIENT8_TESTNET2
        ),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.ANCIENT8_TESTNET2),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.ANCIENT8_TESTNET2, txData),
      },
      [ChainSlug.HOOK_TESTNET]: {
        rpc: rpcs[ChainSlug.HOOK_TESTNET],
        chainName: HardhatChainName.HOOK_TESTNET,
        blockNumber: getBlockNumber(
          DeploymentMode.PROD,
          ChainSlug.HOOK_TESTNET
        ),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.HOOK_TESTNET),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.HOOK_TESTNET, txData),
      },
      [ChainSlug.HOOK]: {
        rpc: rpcs[ChainSlug.HOOK],
        chainName: HardhatChainName.HOOK,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.HOOK),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.HOOK),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.HOOK, txData),
      },
      [ChainSlug.PARALLEL]: {
        rpc: rpcs[ChainSlug.PARALLEL],
        chainName: HardhatChainName.PARALLEL,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.PARALLEL),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.PARALLEL),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.PARALLEL, txData),
      },
      [ChainSlug.MANTLE]: {
        rpc: rpcs[ChainSlug.MANTLE],
        chainName: HardhatChainName.MANTLE,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.MANTLE),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.MANTLE),
        nativeToken: NativeTokens.mantle,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.MANTLE, txData),
      },
      [ChainSlug.REYA_CRONOS]: {
        rpc: rpcs[ChainSlug.REYA_CRONOS],
        chainName: HardhatChainName.REYA_CRONOS,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.REYA_CRONOS),
        confirmations: 0,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.REYA_CRONOS),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.arbChain,
        chainTxData: await getChainTxData(ChainSlug.REYA_CRONOS, txData),
      },
      [ChainSlug.REYA]: {
        rpc: rpcs[ChainSlug.REYA],
        chainName: HardhatChainName.REYA,
        blockNumber: getBlockNumber(DeploymentMode.PROD, ChainSlug.REYA),
        confirmations: 0,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.REYA),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.arbChain,
        chainTxData: await getChainTxData(ChainSlug.REYA, txData),
      },
      [ChainSlug.SYNDR_SEPOLIA_L3]: {
        rpc: rpcs[ChainSlug.SYNDR_SEPOLIA_L3],
        chainName: HardhatChainName.SYNDR_SEPOLIA_L3,
        blockNumber: getBlockNumber(
          DeploymentMode.PROD,
          ChainSlug.SYNDR_SEPOLIA_L3
        ),
        confirmations: 1,
        siblings: getSiblings(DeploymentMode.PROD, ChainSlug.SYNDR_SEPOLIA_L3),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.default,
        chainTxData: await getChainTxData(ChainSlug.SYNDR_SEPOLIA_L3, txData),
      },
      [ChainSlug.POLYNOMIAL_TESTNET]: {
        rpc: rpcs[ChainSlug.POLYNOMIAL_TESTNET],
        chainName: HardhatChainName.POLYNOMIAL_TESTNET,
        blockNumber: getBlockNumber(
          DeploymentMode.PROD,
          ChainSlug.POLYNOMIAL_TESTNET
        ),
        confirmations: 1,
        siblings: getSiblings(
          DeploymentMode.PROD,
          ChainSlug.POLYNOMIAL_TESTNET
        ),
        nativeToken: NativeTokens.ethereum,
        chainType: ChainType.opStackL2Chain,
        chainTxData: await getChainTxData(ChainSlug.POLYNOMIAL_TESTNET, txData),
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
      ChainSlug.PARALLEL,
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
