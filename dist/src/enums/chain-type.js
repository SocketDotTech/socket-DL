"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ethLikeChains = exports.polygonCDKChains = exports.arbChains = exports.arbL3Chains = exports.opStackL2Chain = void 0;
const chainSlug_1 = require("./chainSlug");
exports.opStackL2Chain = [
    chainSlug_1.ChainSlug.AEVO,
    chainSlug_1.ChainSlug.AEVO_TESTNET,
    chainSlug_1.ChainSlug.LYRA,
    chainSlug_1.ChainSlug.MODE_TESTNET,
    chainSlug_1.ChainSlug.LYRA_TESTNET,
    chainSlug_1.ChainSlug.MODE,
    chainSlug_1.ChainSlug.OPTIMISM,
    chainSlug_1.ChainSlug.OPTIMISM_SEPOLIA,
    chainSlug_1.ChainSlug.OPTIMISM_GOERLI,
    chainSlug_1.ChainSlug.BASE,
    chainSlug_1.ChainSlug.MANTLE,
    chainSlug_1.ChainSlug.POLYNOMIAL_TESTNET,
];
exports.arbL3Chains = [
    chainSlug_1.ChainSlug.HOOK_TESTNET,
    chainSlug_1.ChainSlug.HOOK,
    chainSlug_1.ChainSlug.SYNDR_SEPOLIA_L3,
];
exports.arbChains = [
    chainSlug_1.ChainSlug.ARBITRUM,
    chainSlug_1.ChainSlug.ARBITRUM_GOERLI,
    chainSlug_1.ChainSlug.ARBITRUM_SEPOLIA,
    chainSlug_1.ChainSlug.PARALLEL,
];
exports.polygonCDKChains = [
    chainSlug_1.ChainSlug.CDK_TESTNET,
    chainSlug_1.ChainSlug.ANCIENT8_TESTNET2,
    chainSlug_1.ChainSlug.SX_NETWORK_TESTNET,
    chainSlug_1.ChainSlug.SX_NETWORK,
    chainSlug_1.ChainSlug.XAI_TESTNET,
];
// chains having constant gas limits
exports.ethLikeChains = [
    chainSlug_1.ChainSlug.MAINNET,
    chainSlug_1.ChainSlug.BSC,
    chainSlug_1.ChainSlug.BSC_TESTNET,
    chainSlug_1.ChainSlug.POLYGON_MAINNET,
    chainSlug_1.ChainSlug.POLYGON_MUMBAI,
    chainSlug_1.ChainSlug.SEPOLIA,
    chainSlug_1.ChainSlug.SX_NETWORK,
    chainSlug_1.ChainSlug.SX_NETWORK_TESTNET,
    chainSlug_1.ChainSlug.ANCIENT8_TESTNET,
    chainSlug_1.ChainSlug.ANCIENT8_TESTNET2,
    chainSlug_1.ChainSlug.REYA_CRONOS,
    chainSlug_1.ChainSlug.REYA,
    chainSlug_1.ChainSlug.BSC_TESTNET,
    chainSlug_1.ChainSlug.GOERLI,
    chainSlug_1.ChainSlug.VICTION_TESTNET,
    chainSlug_1.ChainSlug.SYNDR_SEPOLIA_L3,
];
