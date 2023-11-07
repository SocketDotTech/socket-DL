import { ChainSlug, MainnetIds, TestnetIds } from "./chain-types";

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
