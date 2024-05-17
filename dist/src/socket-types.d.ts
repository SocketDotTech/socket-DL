import { ChainSlug, NativeTokens } from "./enums";
export declare const L1Ids: ChainSlug[];
export declare const L2Ids: ChainSlug[];
export declare enum NativeSwitchboard {
    NON_NATIVE = 0,
    ARBITRUM_L1 = 1,
    ARBITRUM_L2 = 2,
    OPTIMISM = 3,
    POLYGON_L1 = 4,
    POLYGON_L2 = 5
}
/***********************************************
 *                                             *
 * Update above values when new chain is added *
 *                                             *
 ***********************************************/
export declare const isTestnet: (chainSlug: ChainSlug) => boolean;
export declare const isMainnet: (chainSlug: ChainSlug) => boolean;
export declare const isL1: (chainSlug: ChainSlug) => boolean;
export declare const isL2: (chainSlug: ChainSlug) => boolean;
export declare const isNonNativeChain: (chainSlug: ChainSlug) => boolean;
export declare enum IntegrationTypes {
    fast2 = "FAST2",
    fast = "FAST",
    optimistic = "OPTIMISTIC",
    native = "NATIVE_BRIDGE",
    unknown = "UNKNOWN"
}
export declare enum DeploymentMode {
    DEV = "dev",
    PROD = "prod",
    SURGE = "surge"
}
export declare enum CapacitorType {
    singleCapacitor = "1",
    hashChainCapacitor = "2"
}
export type Integrations = {
    [chainSlug in ChainSlug]?: ChainAddresses;
};
export type ChainAddresses = {
    [integration in IntegrationTypes]?: Configs;
};
export type Configs = {
    switchboard?: string;
    capacitor?: string;
    decapacitor?: string;
};
export interface ChainSocketAddresses {
    startBlock?: number;
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
    SocketSimulator?: string;
    SimulatorUtils?: string;
    SwitchboardSimulator?: string;
    KintoDeployer?: string;
}
export type DeploymentAddresses = {
    [chainSlug in ChainSlug]?: ChainSocketAddresses;
};
export declare enum ROLES {
    TRANSMITTER_ROLE = "TRANSMITTER_ROLE",
    RESCUE_ROLE = "RESCUE_ROLE",
    WITHDRAW_ROLE = "WITHDRAW_ROLE",
    GOVERNANCE_ROLE = "GOVERNANCE_ROLE",
    EXECUTOR_ROLE = "EXECUTOR_ROLE",
    TRIP_ROLE = "TRIP_ROLE",
    UN_TRIP_ROLE = "UN_TRIP_ROLE",
    WATCHER_ROLE = "WATCHER_ROLE",
    FEES_UPDATER_ROLE = "FEES_UPDATER_ROLE",
    SOCKET_RELAYER_ROLE = "SOCKET_RELAYER_ROLE"
}
export declare enum CORE_CONTRACTS {
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
    NativeSwitchboard = "NativeSwitchboard"
}
export declare const REQUIRED_ROLES: {
    CapacitorFactory: ROLES[];
    ExecutionManager: ROLES[];
    OpenExecutionManager: ROLES[];
    TransmitManager: ROLES[];
    Socket: ROLES[];
    FastSwitchboard: ROLES[];
    FastSwitchboard2: ROLES[];
    OptimisticSwitchboard: ROLES[];
    NativeSwitchboard: ROLES[];
};
export declare const REQUIRED_CHAIN_ROLES: {
    TransmitManager: ROLES[];
    ExecutionManager: ROLES[];
    OpenExecutionManager: ROLES[];
    FastSwitchboard: ROLES[];
    FastSwitchboard2: ROLES[];
    OptimisticSwitchboard: ROLES[];
};
export declare enum ChainType {
    opStackL2Chain = "opStackL2Chain",
    arbL3Chain = "arbL3Chain",
    arbChain = "arbChain",
    polygonCDKChain = "polygonCDKChain",
    default = "default"
}
export type TxData = {
    [chainSlug in ChainSlug]?: ChainTxData;
};
export interface ChainTxData {
    sealTxData: any[];
    proposeTxData: any[];
    attestTxData: any[];
    owner: string;
}
export interface S3ChainConfig {
    rpc: string;
    blockNumber: number;
    confirmations: number;
    siblings: ChainSlug[];
    chainName: string;
    eventBlockRange?: number;
    nativeToken?: NativeTokens;
    chainType?: ChainType;
    chainTxData?: ChainTxData;
}
export type S3Config = {
    version: string;
    chainSlugToId: {
        [chainSlug: number]: number;
    };
    addresses: DeploymentAddresses;
    testnetIds: ChainSlug[];
    mainnetIds: ChainSlug[];
    chains: {
        [chainSlug in ChainSlug]?: S3ChainConfig;
    };
    batcherSupportedChainSlugs: ChainSlug[];
    watcherSupportedChainSlugs: ChainSlug[];
    nativeSupportedChainSlugs: ChainSlug[];
    feeUpdaterSupportedChainSlugs: ChainSlug[];
};
