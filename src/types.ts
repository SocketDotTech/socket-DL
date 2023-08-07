/***********************************************
 *                                             *
 * Update below values when new chain is added *
 *                                             *
 ***********************************************/

export enum ChainSlug {
  ARBITRUM = 42161,
  ARBITRUM_GOERLI = 421613,
  OPTIMISM = 10,
  OPTIMISM_GOERLI = 420,
  BSC = 56,
  BSC_TESTNET = 97,
  MAINNET = 1,
  GOERLI = 5,
  SEPOLIA = 11155111,
  POLYGON_MAINNET = 137,
  POLYGON_MUMBAI = 80001,
  AEVO_TESTNET = 11155112,
  AEVO = 2999,
  HARDHAT = 31337,
}

export enum ChainKey {
  ARBITRUM = "arbitrum",
  ARBITRUM_GOERLI = "arbitrum-goerli",
  OPTIMISM = "optimism",
  OPTIMISM_GOERLI = "optimism-goerli",
  AVALANCHE = "avalanche",
  AVALANCHE_TESTNET = "avalanche-testnet",
  BSC = "bsc",
  BSC_TESTNET = "bsc-testnet",
  MAINNET = "mainnet",
  GOERLI = "goerli",
  SEPOLIA = "sepolia",
  POLYGON_MAINNET = "polygon-mainnet",
  POLYGON_MUMBAI = "polygon-mumbai",
  AEVO_TESTNET = "aevo-testnet",
  AEVO = "aevo",
  HARDHAT = "hardhat",
}

export const chainKeyToSlug = {
  [ChainKey.ARBITRUM]: 42161,
  [ChainKey.ARBITRUM_GOERLI]: 421613,
  [ChainKey.OPTIMISM]: 10,
  [ChainKey.OPTIMISM_GOERLI]: 420,
  [ChainKey.AVALANCHE]: 43114,
  [ChainKey.BSC]: 56,
  [ChainKey.BSC_TESTNET]: 97,
  [ChainKey.MAINNET]: 1,
  [ChainKey.GOERLI]: 5,
  [ChainKey.SEPOLIA]: 11155111,
  [ChainKey.POLYGON_MAINNET]: 137,
  [ChainKey.POLYGON_MUMBAI]: 80001,
  [ChainKey.AEVO_TESTNET]: 11155112,
  [ChainKey.AEVO]: 2999,
  [ChainKey.HARDHAT]: 31337,
};

export const ChainSlugToKey = {
  43114: ChainKey.AVALANCHE,
  56: ChainKey.BSC,
  5: ChainKey.GOERLI,
  11155111: ChainKey.SEPOLIA,
  31337: ChainKey.HARDHAT,
  1: ChainKey.MAINNET,
  97: ChainKey.BSC_TESTNET,
  42161: ChainKey.ARBITRUM,
  421613: ChainKey.ARBITRUM_GOERLI,
  10: ChainKey.OPTIMISM,
  420: ChainKey.OPTIMISM_GOERLI,
  137: ChainKey.POLYGON_MAINNET,
  80001: ChainKey.POLYGON_MUMBAI,
  11155112: ChainKey.AEVO_TESTNET,
  2999: ChainKey.AEVO,
};

export const TestnetIds: ChainSlug[] = [
  ChainSlug.GOERLI,
  ChainSlug.SEPOLIA,
  ChainSlug.POLYGON_MUMBAI,
  ChainSlug.ARBITRUM_GOERLI,
  ChainSlug.OPTIMISM_GOERLI,
  ChainSlug.BSC_TESTNET,
  ChainSlug.AEVO_TESTNET,
];

export const MainnetIds: ChainSlug[] = [
  ChainSlug.MAINNET,
  ChainSlug.POLYGON_MAINNET,
  ChainSlug.ARBITRUM,
  ChainSlug.OPTIMISM,
  ChainSlug.BSC,
  ChainSlug.AEVO,
];

export const L1Ids: ChainSlug[] = [ChainSlug.MAINNET, ChainSlug.GOERLI];

export const L2Ids: ChainSlug[] = [
  ChainSlug.POLYGON_MUMBAI,
  ChainSlug.ARBITRUM_GOERLI,
  ChainSlug.OPTIMISM_GOERLI,
  ChainSlug.POLYGON_MAINNET,
  ChainSlug.ARBITRUM,
  ChainSlug.OPTIMISM,
];

export enum NativeSwitchboard {
  NON_NATIVE = 0,
  ARBITRUM_L1 = 1,
  ARBITRUM_L2 = 2,
  OPTIMISM = 3,
  POLYGON_L1 = 4,
  POLYGON_L2 = 5,
}

/***********************************************
 *                                             *
 * Update above values when new chain is added *
 *                                             *
 ***********************************************/

// export const MainnetIds: ChainSlug[] = (
//   Object.values(ChainSlug) as ChainSlug[]
// ).filter((c) => !TestnetIds.includes(c));

export const isTestnet = (chainSlug: ChainSlug) => {
  return TestnetIds.includes(chainSlug);
};

export const isMainnet = (chainSlug: ChainSlug) => {
  return MainnetIds.includes(chainSlug);
};

export const isL1 = (chainSlug: ChainSlug) => {
  return L1Ids.includes(chainSlug);
};

export const isL2 = (chainSlug: ChainSlug) => {
  return L2Ids.includes(chainSlug);
};

export const isNonNativeChain = (chainSlug: ChainSlug) => {
  return !L1Ids.includes(chainSlug) && !L2Ids.includes(chainSlug);
};

export enum IntegrationTypes {
  fast = "FAST",
  optimistic = "OPTIMISTIC",
  native = "NATIVE_BRIDGE",
  unknown = "UNKNOWN",
}

export enum DeploymentMode {
  DEV = "dev",
  PROD = "prod",
  SURGE = "surge",
}

export enum CapacitorType {
  singleCapacitor = "1",
  hashChainCapacitor = "2",
}

export type Integrations = { [chainSlug in ChainSlug]?: ChainAddresses };
export type ChainAddresses = { [integration in IntegrationTypes]?: Configs };
export type Configs = {
  switchboard?: string;
  capacitor?: string;
  decapacitor?: string;
};

export interface ChainSocketAddresses {
  Counter: string;
  CapacitorFactory: string;
  ExecutionManager?: string;
  Hasher: string;
  SignatureVerifier: string;
  Socket: string;
  TransmitManager: string;
  FastSwitchboard: string;
  OptimisticSwitchboard: string;
  SocketBatcher: string;
  integrations?: Integrations;
  OpenExecutionManager?: string;
}

export type DeploymentAddresses = {
  [chainSlug in ChainSlug]?: ChainSocketAddresses;
};

export enum ROLES {
  TRANSMITTER_ROLE = "TRANSMITTER_ROLE",
  RESCUE_ROLE = "RESCUE_ROLE",
  WITHDRAW_ROLE = "WITHDRAW_ROLE",
  GOVERNANCE_ROLE = "GOVERNANCE_ROLE",
  EXECUTOR_ROLE = "EXECUTOR_ROLE",
  TRIP_ROLE = "TRIP_ROLE",
  UN_TRIP_ROLE = "UN_TRIP_ROLE",
  WATCHER_ROLE = "WATCHER_ROLE",
  FEES_UPDATER_ROLE = "FEES_UPDATER_ROLE",
}

export enum CORE_CONTRACTS {
  CapacitorFactory = "CapacitorFactory",
  ExecutionManager = "ExecutionManager",
  OpenExecutionManager = "OpenExecutionManager",
  Hasher = "Hasher",
  SignatureVerifier = "SignatureVerifier",
  TransmitManager = "TransmitManager",
  Socket = "Socket",
  SocketBatcher = "SocketBatcher",
  FastSwitchboard = "FastSwitchboard",
  OptimisticSwitchboard = "OptimisticSwitchboard",
  NativeSwitchboard = "NativeSwitchboard",
}

export const REQUIRED_ROLES = {
  CapacitorFactory: [ROLES.RESCUE_ROLE],
  ExecutionManager: [
    ROLES.WITHDRAW_ROLE,
    ROLES.RESCUE_ROLE,
    ROLES.GOVERNANCE_ROLE,
    ROLES.EXECUTOR_ROLE,
  ],
  OpenExecutionManager: [
    ROLES.WITHDRAW_ROLE,
    ROLES.RESCUE_ROLE,
    ROLES.GOVERNANCE_ROLE,
    ROLES.EXECUTOR_ROLE,
  ],
  TransmitManager: [
    ROLES.GOVERNANCE_ROLE,
    ROLES.WITHDRAW_ROLE,
    ROLES.RESCUE_ROLE,
  ],
  Socket: [ROLES.RESCUE_ROLE, ROLES.GOVERNANCE_ROLE],
  FastSwitchboard: [
    ROLES.TRIP_ROLE,
    ROLES.UN_TRIP_ROLE,
    ROLES.GOVERNANCE_ROLE,
    ROLES.WITHDRAW_ROLE,
    ROLES.RESCUE_ROLE,
  ],
  OptimisticSwitchboard: [
    ROLES.TRIP_ROLE,
    ROLES.UN_TRIP_ROLE,
    ROLES.GOVERNANCE_ROLE,
    ROLES.WITHDRAW_ROLE,
    ROLES.RESCUE_ROLE,
  ],
  NativeSwitchboard: [
    ROLES.FEES_UPDATER_ROLE,
    ROLES.TRIP_ROLE,
    ROLES.UN_TRIP_ROLE,
    ROLES.GOVERNANCE_ROLE,
    ROLES.WITHDRAW_ROLE,
    ROLES.RESCUE_ROLE,
  ],
};

export const REQUIRED_CHAIN_ROLES = {
  TransmitManager: [ROLES.TRANSMITTER_ROLE, ROLES.FEES_UPDATER_ROLE],
  [CORE_CONTRACTS.ExecutionManager]: [ROLES.FEES_UPDATER_ROLE],
  [CORE_CONTRACTS.OpenExecutionManager]: [ROLES.FEES_UPDATER_ROLE],
  FastSwitchboard: [ROLES.WATCHER_ROLE, ROLES.FEES_UPDATER_ROLE],
  OptimisticSwitchboard: [ROLES.WATCHER_ROLE, ROLES.FEES_UPDATER_ROLE],
};
