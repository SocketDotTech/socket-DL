"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChainType = exports.REQUIRED_CHAIN_ROLES = exports.REQUIRED_ROLES = exports.CORE_CONTRACTS = exports.ROLES = exports.CapacitorType = exports.DeploymentMode = exports.IntegrationTypes = exports.isNonNativeChain = exports.isL2 = exports.isL1 = exports.isMainnet = exports.isTestnet = exports.NativeSwitchboard = exports.L2Ids = exports.L1Ids = void 0;
const enums_1 = require("./enums");
exports.L1Ids = [
    enums_1.ChainSlug.MAINNET,
    enums_1.ChainSlug.GOERLI,
    enums_1.ChainSlug.SEPOLIA,
];
exports.L2Ids = [
    enums_1.ChainSlug.POLYGON_MUMBAI,
    enums_1.ChainSlug.ARBITRUM_GOERLI,
    enums_1.ChainSlug.OPTIMISM_GOERLI,
    enums_1.ChainSlug.ARBITRUM_SEPOLIA,
    enums_1.ChainSlug.OPTIMISM_SEPOLIA,
    enums_1.ChainSlug.POLYGON_MAINNET,
    enums_1.ChainSlug.ARBITRUM,
    enums_1.ChainSlug.OPTIMISM,
    enums_1.ChainSlug.AEVO,
    enums_1.ChainSlug.AEVO_TESTNET,
    enums_1.ChainSlug.LYRA_TESTNET,
    enums_1.ChainSlug.LYRA,
    enums_1.ChainSlug.XAI_TESTNET,
];
var NativeSwitchboard;
(function (NativeSwitchboard) {
    NativeSwitchboard[NativeSwitchboard["NON_NATIVE"] = 0] = "NON_NATIVE";
    NativeSwitchboard[NativeSwitchboard["ARBITRUM_L1"] = 1] = "ARBITRUM_L1";
    NativeSwitchboard[NativeSwitchboard["ARBITRUM_L2"] = 2] = "ARBITRUM_L2";
    NativeSwitchboard[NativeSwitchboard["OPTIMISM"] = 3] = "OPTIMISM";
    NativeSwitchboard[NativeSwitchboard["POLYGON_L1"] = 4] = "POLYGON_L1";
    NativeSwitchboard[NativeSwitchboard["POLYGON_L2"] = 5] = "POLYGON_L2";
})(NativeSwitchboard = exports.NativeSwitchboard || (exports.NativeSwitchboard = {}));
/***********************************************
 *                                             *
 * Update above values when new chain is added *
 *                                             *
 ***********************************************/
// export const MainnetIds: ChainSlug[] = (
//   Object.values(ChainSlug) as ChainSlug[]
// ).filter((c) => !TestnetIds.includes(c));
const isTestnet = (chainSlug) => {
    return enums_1.TestnetIds.includes(chainSlug);
};
exports.isTestnet = isTestnet;
const isMainnet = (chainSlug) => {
    return enums_1.MainnetIds.includes(chainSlug);
};
exports.isMainnet = isMainnet;
const isL1 = (chainSlug) => {
    return exports.L1Ids.includes(chainSlug);
};
exports.isL1 = isL1;
const isL2 = (chainSlug) => {
    return exports.L2Ids.includes(chainSlug);
};
exports.isL2 = isL2;
const isNonNativeChain = (chainSlug) => {
    return !exports.L1Ids.includes(chainSlug) && !exports.L2Ids.includes(chainSlug);
};
exports.isNonNativeChain = isNonNativeChain;
var IntegrationTypes;
(function (IntegrationTypes) {
    IntegrationTypes["fast2"] = "FAST2";
    IntegrationTypes["fast"] = "FAST";
    IntegrationTypes["optimistic"] = "OPTIMISTIC";
    IntegrationTypes["native"] = "NATIVE_BRIDGE";
    IntegrationTypes["unknown"] = "UNKNOWN";
})(IntegrationTypes = exports.IntegrationTypes || (exports.IntegrationTypes = {}));
var DeploymentMode;
(function (DeploymentMode) {
    DeploymentMode["DEV"] = "dev";
    DeploymentMode["PROD"] = "prod";
    DeploymentMode["SURGE"] = "surge";
})(DeploymentMode = exports.DeploymentMode || (exports.DeploymentMode = {}));
var CapacitorType;
(function (CapacitorType) {
    CapacitorType["singleCapacitor"] = "1";
    CapacitorType["hashChainCapacitor"] = "2";
})(CapacitorType = exports.CapacitorType || (exports.CapacitorType = {}));
var ROLES;
(function (ROLES) {
    ROLES["TRANSMITTER_ROLE"] = "TRANSMITTER_ROLE";
    ROLES["RESCUE_ROLE"] = "RESCUE_ROLE";
    ROLES["WITHDRAW_ROLE"] = "WITHDRAW_ROLE";
    ROLES["GOVERNANCE_ROLE"] = "GOVERNANCE_ROLE";
    ROLES["EXECUTOR_ROLE"] = "EXECUTOR_ROLE";
    ROLES["TRIP_ROLE"] = "TRIP_ROLE";
    ROLES["UN_TRIP_ROLE"] = "UN_TRIP_ROLE";
    ROLES["WATCHER_ROLE"] = "WATCHER_ROLE";
    ROLES["FEES_UPDATER_ROLE"] = "FEES_UPDATER_ROLE";
    ROLES["SOCKET_RELAYER_ROLE"] = "SOCKET_RELAYER_ROLE";
})(ROLES = exports.ROLES || (exports.ROLES = {}));
var CORE_CONTRACTS;
(function (CORE_CONTRACTS) {
    CORE_CONTRACTS["CapacitorFactory"] = "CapacitorFactory";
    CORE_CONTRACTS["ExecutionManager"] = "ExecutionManager";
    CORE_CONTRACTS["OpenExecutionManager"] = "OpenExecutionManager";
    CORE_CONTRACTS["Hasher"] = "Hasher";
    CORE_CONTRACTS["SignatureVerifier"] = "SignatureVerifier";
    CORE_CONTRACTS["TransmitManager"] = "TransmitManager";
    CORE_CONTRACTS["Socket"] = "Socket";
    CORE_CONTRACTS["SocketBatcher"] = "SocketBatcher";
    CORE_CONTRACTS["FastSwitchboard"] = "FastSwitchboard";
    CORE_CONTRACTS["FastSwitchboard2"] = "FastSwitchboard2";
    CORE_CONTRACTS["OptimisticSwitchboard"] = "OptimisticSwitchboard";
    CORE_CONTRACTS["NativeSwitchboard"] = "NativeSwitchboard";
})(CORE_CONTRACTS = exports.CORE_CONTRACTS || (exports.CORE_CONTRACTS = {}));
exports.REQUIRED_ROLES = {
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
exports.REQUIRED_CHAIN_ROLES = {
    TransmitManager: [ROLES.TRANSMITTER_ROLE, ROLES.FEES_UPDATER_ROLE],
    [CORE_CONTRACTS.ExecutionManager]: [ROLES.FEES_UPDATER_ROLE],
    [CORE_CONTRACTS.OpenExecutionManager]: [ROLES.FEES_UPDATER_ROLE],
    FastSwitchboard: [ROLES.WATCHER_ROLE, ROLES.FEES_UPDATER_ROLE],
    FastSwitchboard2: [ROLES.WATCHER_ROLE, ROLES.FEES_UPDATER_ROLE],
    OptimisticSwitchboard: [ROLES.WATCHER_ROLE, ROLES.FEES_UPDATER_ROLE],
};
var ChainType;
(function (ChainType) {
    ChainType["opStackL2Chain"] = "opStackL2Chain";
    ChainType["arbL3Chain"] = "arbL3Chain";
    ChainType["arbChain"] = "arbChain";
    ChainType["polygonCDKChain"] = "polygonCDKChain";
    ChainType["default"] = "default";
})(ChainType = exports.ChainType || (exports.ChainType = {}));
