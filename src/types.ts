/***********************************************
 *                                             *
 * Update below values when new chain is added *
 *                                             *
 ***********************************************/

export enum ChainSlug {
  GOERLI = 5,
  MUMBAI = 80001,
  ARBITRUM_TESTNET = 421613,
  OPTIMISM_TESTNET = 420,
  BSC_TESTNET = 97,
  MAINNET = 1,
  POLYGON = 137,
  ARBITRUM = 42161,
  OPTIMISM = 10,
  BSC = 56,
}

export const TestnetIds: ChainSlug[] = [
  ChainSlug.GOERLI,
  ChainSlug.MUMBAI,
  ChainSlug.ARBITRUM_TESTNET,
  ChainSlug.OPTIMISM_TESTNET,
  ChainSlug.BSC_TESTNET,
];

export const L1Ids: ChainSlug[] = [ChainSlug.MAINNET, ChainSlug.GOERLI];

export const L2Ids: ChainSlug[] = [
  ChainSlug.MUMBAI,
  ChainSlug.ARBITRUM_TESTNET,
  ChainSlug.OPTIMISM_TESTNET,
  ChainSlug.POLYGON,
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

export const MainnetIds: ChainSlug[] = (
  Object.values(ChainSlug) as ChainSlug[]
).filter((c) => !TestnetIds.includes(c));

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
  ExecutionManager: string;
  GasPriceOracle: string;
  Hasher: string;
  SignatureVerifier: string;
  Socket: string;
  TransmitManager: string;
  FastSwitchboard?: string;
  OptimisticSwitchboard?: string;
  integrations?: Integrations;
  SocketBatcher?: string;
}

export type DeploymentAddresses = {
  [chainSlug in ChainSlug]?: ChainSocketAddresses;
};

export enum ROLES {
  TRANSMITTER_ROLE = "TRANSMITTER_ROLE",
  GAS_LIMIT_UPDATER_ROLE = "GAS_LIMIT_UPDATER_ROLE",
  RESCUE_ROLE = "RESCUE_ROLE",
  WITHDRAW_ROLE = "WITHDRAW_ROLE",
  GOVERNANCE_ROLE = "GOVERNANCE_ROLE",
  EXECUTOR_ROLE = "EXECUTOR_ROLE",
  TRIP_ROLE = "TRIP_ROLE",
  UNTRIP_ROLE = "UNTRIP_ROLE",
  WATCHER_ROLE = "WATCHER_ROLE"
}


export const REQUIRED_ROLES = {
  "CapacitorFactory":[ROLES.RESCUE_ROLE],
  "ExecutionManager":[ROLES.WITHDRAW_ROLE, ROLES.RESCUE_ROLE, ROLES.GOVERNANCE_ROLE, ROLES.EXECUTOR_ROLE],
  "TransmitManager":[ROLES.GOVERNANCE_ROLE, ROLES.WITHDRAW_ROLE, ROLES.RESCUE_ROLE, ROLES.EXECUTOR_ROLE],
  "GasPriceOracle":[ROLES.GOVERNANCE_ROLE, ROLES.RESCUE_ROLE],
  "Socket":[ROLES.RESCUE_ROLE, ROLES.GOVERNANCE_ROLE],
  "FastSwitchboard":[ROLES.TRIP_ROLE, ROLES.UNTRIP_ROLE, ROLES.GOVERNANCE_ROLE, ROLES.WITHDRAW_ROLE, ROLES.RESCUE_ROLE],
  "OptimisticSwitchboard":[ROLES.TRIP_ROLE, ROLES.UNTRIP_ROLE, ROLES.GOVERNANCE_ROLE, ROLES.WITHDRAW_ROLE, ROLES.RESCUE_ROLE],
  "NativeSwitchboard":[ROLES.GAS_LIMIT_UPDATER_ROLE, ROLES.TRIP_ROLE, ROLES.UNTRIP_ROLE, ROLES.GOVERNANCE_ROLE, ROLES.WITHDRAW_ROLE, ROLES.RESCUE_ROLE]
}

export const REQUIRED_CHAIN_ROLES = {
  "TransmitManager":[ROLES.TRANSMITTER_ROLE, ROLES.GAS_LIMIT_UPDATER_ROLE],
  "FastSwitchboard":[ROLES.WATCHER_ROLE,  ROLES.TRIP_ROLE, ROLES.UNTRIP_ROLE, ROLES.GAS_LIMIT_UPDATER_ROLE],
  "OptimisticSwitchboard":[ ROLES.TRIP_ROLE, ROLES.UNTRIP_ROLE, ROLES.GAS_LIMIT_UPDATER_ROLE]
}

// CapacitorFactory: RESCUE_ROLE
// ExecutionManager: WITHDRAW_ROLE, RESCUE_ROLE, GOVERNANCE_ROLE, EXECUTOR_ROLE
// TransmitManager: GOVERNANCE_ROLE, WITHDRAW_ROLE, RESCUE_ROLE, GAS_LIMIT_UPDATER_ROLE
// GasPriceOracle: GOVERNANCE_ROLE, RESCUE_ROLE
// Socket: RESCUE_ROLE, GOVERNANCE_ROLE
// Switchboards: 
// all: TRIP_ROLE, UNTRIP_ROLE, GOVERNANCE_ROLE, WITHDRAW_ROLE, RESCUE_ROLE
// native:GAS_LIMIT_UPDATER_ROLE
// Capacitor: RESCUE_ROLE
// Decapacitor: RESCUE_ROLE
// default:TRIP_ROLE(chain), UNTRIP_ROLE(chain), GAS_LIMIT_UPDATER_ROLE(chain),
// fast: WATCHER_ROLE(chain)
// in configure:
// TransmitManager: TRANSMITTER_ROLE(chain), GAS_LIMIT_UPDATER_ROLE(chain)