/***********************************************
 *                                             *
 * Update below values when new chain is added *
 *                                             *
 ***********************************************/

export enum HardhatChainName {
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
  LYRA_TESTNET = "lyra-testnet",
  LYRA = "lyra",
  XAI_TESTNET = "xai_testnet",
  HARDHAT = "hardhat",
}

export enum ChainId {
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
  AVALANCHE = 43114,
  LYRA_TESTNET = 901,
  LYRA = 0, // update this
  XAI_TESTNET = 47279324479,
}

export enum ChainSlug {
  ARBITRUM = ChainId.ARBITRUM,
  ARBITRUM_GOERLI = ChainId.ARBITRUM_GOERLI,
  OPTIMISM = ChainId.OPTIMISM,
  OPTIMISM_GOERLI = ChainId.OPTIMISM_GOERLI,
  BSC = ChainId.BSC,
  BSC_TESTNET = ChainId.BSC_TESTNET,
  MAINNET = ChainId.MAINNET,
  GOERLI = ChainId.GOERLI,
  SEPOLIA = ChainId.SEPOLIA,
  POLYGON_MAINNET = ChainId.POLYGON_MAINNET,
  POLYGON_MUMBAI = ChainId.POLYGON_MUMBAI,
  AEVO_TESTNET = ChainId.AEVO_TESTNET,
  AEVO = ChainId.AEVO,
  HARDHAT = ChainId.HARDHAT,
  AVALANCHE = ChainId.AVALANCHE,
  LYRA_TESTNET = ChainId.LYRA_TESTNET,
  LYRA = ChainId.LYRA,
  XAI_TESTNET = 1399904803,
}

export const ChainSlugToId = {
  [ChainSlug.AVALANCHE]: ChainId.AVALANCHE,
  [ChainSlug.BSC]: ChainId.BSC,
  [ChainSlug.GOERLI]: ChainId.GOERLI,
  [ChainSlug.SEPOLIA]: ChainId.SEPOLIA,
  [ChainSlug.HARDHAT]: ChainId.HARDHAT,
  [ChainSlug.MAINNET]: ChainId.MAINNET,
  [ChainSlug.BSC_TESTNET]: ChainId.BSC_TESTNET,
  [ChainSlug.ARBITRUM]: ChainId.ARBITRUM,
  [ChainSlug.ARBITRUM_GOERLI]: ChainId.ARBITRUM_GOERLI,
  [ChainSlug.OPTIMISM]: ChainId.OPTIMISM,
  [ChainSlug.OPTIMISM_GOERLI]: ChainId.OPTIMISM_GOERLI,
  [ChainSlug.POLYGON_MAINNET]: ChainId.POLYGON_MAINNET,
  [ChainSlug.POLYGON_MUMBAI]: ChainId.POLYGON_MUMBAI,
  [ChainSlug.AEVO_TESTNET]: ChainId.AEVO_TESTNET,
  [ChainSlug.LYRA_TESTNET]: ChainId.LYRA_TESTNET,
  [ChainSlug.LYRA]: ChainId.LYRA,
  [ChainSlug.AEVO]: ChainId.AEVO,
  [ChainSlug.XAI_TESTNET]: ChainId.XAI_TESTNET,
};

export const hardhatChainNameToSlug = {
  [HardhatChainName.ARBITRUM]: ChainSlug.ARBITRUM,
  [HardhatChainName.ARBITRUM_GOERLI]: ChainSlug.ARBITRUM_GOERLI,
  [HardhatChainName.OPTIMISM]: ChainSlug.OPTIMISM,
  [HardhatChainName.OPTIMISM_GOERLI]: ChainSlug.OPTIMISM_GOERLI,
  [HardhatChainName.BSC]: ChainSlug.BSC,
  [HardhatChainName.BSC_TESTNET]: ChainSlug.BSC_TESTNET,
  [HardhatChainName.MAINNET]: ChainSlug.MAINNET,
  [HardhatChainName.GOERLI]: ChainSlug.GOERLI,
  [HardhatChainName.SEPOLIA]: ChainSlug.SEPOLIA,
  [HardhatChainName.POLYGON_MAINNET]: ChainSlug.POLYGON_MAINNET,
  [HardhatChainName.POLYGON_MUMBAI]: ChainSlug.POLYGON_MUMBAI,
  [HardhatChainName.AEVO_TESTNET]: ChainSlug.AEVO_TESTNET,
  [HardhatChainName.AEVO]: ChainSlug.AEVO,
  [HardhatChainName.LYRA_TESTNET]: ChainSlug.LYRA_TESTNET,
  [HardhatChainName.LYRA]: ChainSlug.LYRA,
  [HardhatChainName.XAI_TESTNET]: ChainSlug.XAI_TESTNET,
  [HardhatChainName.HARDHAT]: ChainSlug.HARDHAT,
};

export const ChainSlugToKey = {
  [ChainSlug.AVALANCHE]: HardhatChainName.AVALANCHE,
  [ChainSlug.BSC]: HardhatChainName.BSC,
  [ChainSlug.GOERLI]: HardhatChainName.GOERLI,
  [ChainSlug.SEPOLIA]: HardhatChainName.SEPOLIA,
  [ChainSlug.HARDHAT]: HardhatChainName.HARDHAT,
  [ChainSlug.MAINNET]: HardhatChainName.MAINNET,
  [ChainSlug.BSC_TESTNET]: HardhatChainName.BSC_TESTNET,
  [ChainSlug.ARBITRUM]: HardhatChainName.ARBITRUM,
  [ChainSlug.ARBITRUM_GOERLI]: HardhatChainName.ARBITRUM_GOERLI,
  [ChainSlug.OPTIMISM]: HardhatChainName.OPTIMISM,
  [ChainSlug.OPTIMISM_GOERLI]: HardhatChainName.OPTIMISM_GOERLI,
  [ChainSlug.POLYGON_MAINNET]: HardhatChainName.POLYGON_MAINNET,
  [ChainSlug.POLYGON_MUMBAI]: HardhatChainName.POLYGON_MUMBAI,
  [ChainSlug.AEVO_TESTNET]: HardhatChainName.AEVO_TESTNET,
  [ChainSlug.LYRA_TESTNET]: HardhatChainName.LYRA_TESTNET,
  [ChainSlug.LYRA]: HardhatChainName.LYRA,
  [ChainSlug.AEVO]: HardhatChainName.AEVO,
  [ChainSlug.XAI_TESTNET]: HardhatChainName.XAI_TESTNET,
};

export const TestnetIds: ChainSlug[] = [
  ChainSlug.GOERLI,
  ChainSlug.SEPOLIA,
  ChainSlug.POLYGON_MUMBAI,
  ChainSlug.ARBITRUM_GOERLI,
  ChainSlug.OPTIMISM_GOERLI,
  ChainSlug.BSC_TESTNET,
  ChainSlug.AEVO_TESTNET,
  ChainSlug.LYRA_TESTNET,
  ChainSlug.XAI_TESTNET,
];

export const MainnetIds: ChainSlug[] = [
  ChainSlug.MAINNET,
  ChainSlug.POLYGON_MAINNET,
  ChainSlug.ARBITRUM,
  ChainSlug.OPTIMISM,
  ChainSlug.BSC,
  ChainSlug.AEVO,
  ChainSlug.LYRA,
];

export const L1Ids: ChainSlug[] = [ChainSlug.MAINNET, ChainSlug.GOERLI];

export const L2Ids: ChainSlug[] = [
  ChainSlug.POLYGON_MUMBAI,
  ChainSlug.ARBITRUM_GOERLI,
  ChainSlug.OPTIMISM_GOERLI,
  ChainSlug.POLYGON_MAINNET,
  ChainSlug.ARBITRUM,
  ChainSlug.OPTIMISM,
  ChainSlug.AEVO,
  ChainSlug.AEVO_TESTNET,
  ChainSlug.LYRA_TESTNET,
  ChainSlug.LYRA,
  ChainSlug.XAI_TESTNET,
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
  fast2 = "FAST2",
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
  FastSwitchboard2?: string;
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
  FastSwitchboard2 = "FastSwitchboard2",
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
  FastSwitchboard2: [
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
  FastSwitchboard2: [ROLES.WATCHER_ROLE, ROLES.FEES_UPDATER_ROLE],
  OptimisticSwitchboard: [ROLES.WATCHER_ROLE, ROLES.FEES_UPDATER_ROLE],
};
