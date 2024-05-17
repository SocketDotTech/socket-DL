"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getProviderFromChainSlug = exports.getJsonRpcUrl = void 0;
const dotenv_1 = require("dotenv");
const ethers_1 = require("ethers");
const path_1 = require("path");
const src_1 = require("../../src");
const dotenvConfigPath = process.env.DOTENV_CONFIG_PATH || "./.env";
(0, dotenv_1.config)({ path: (0, path_1.resolve)(__dirname, dotenvConfigPath) });
function getJsonRpcUrl(chain) {
    let jsonRpcUrl;
    switch (chain) {
        case src_1.HardhatChainName.ARBITRUM:
        case src_1.ChainId.ARBITRUM:
            jsonRpcUrl = process.env.ARBITRUM_RPC;
            break;
        case src_1.HardhatChainName.ARBITRUM_GOERLI:
        case src_1.ChainId.ARBITRUM_GOERLI:
            jsonRpcUrl = process.env.ARB_GOERLI_RPC;
            break;
        case src_1.HardhatChainName.OPTIMISM:
        case src_1.ChainId.OPTIMISM:
            jsonRpcUrl = process.env.OPTIMISM_RPC;
            break;
        case src_1.HardhatChainName.OPTIMISM_GOERLI:
        case src_1.ChainId.OPTIMISM_GOERLI:
            jsonRpcUrl = process.env.OPTIMISM_GOERLI_RPC;
            break;
        case src_1.HardhatChainName.POLYGON_MAINNET:
        case src_1.ChainId.POLYGON_MAINNET:
            jsonRpcUrl = process.env.POLYGON_RPC;
            break;
        case src_1.HardhatChainName.POLYGON_MUMBAI:
        case src_1.ChainId.POLYGON_MUMBAI:
            jsonRpcUrl = process.env.POLYGON_MUMBAI_RPC;
            break;
        case src_1.HardhatChainName.AVALANCHE:
        case src_1.ChainId.AVALANCHE:
            jsonRpcUrl = process.env.AVAX_RPC;
            break;
        case src_1.HardhatChainName.BSC:
        case src_1.ChainId.BSC:
            jsonRpcUrl = process.env.BSC_RPC;
            break;
        case src_1.HardhatChainName.BSC_TESTNET:
        case src_1.ChainId.BSC_TESTNET:
            jsonRpcUrl = process.env.BSC_TESTNET_RPC;
            break;
        case src_1.HardhatChainName.MAINNET:
        case src_1.ChainId.MAINNET:
            jsonRpcUrl = process.env.ETHEREUM_RPC;
            break;
        case src_1.HardhatChainName.GOERLI:
        case src_1.ChainId.GOERLI:
            jsonRpcUrl = process.env.GOERLI_RPC;
            break;
        case src_1.HardhatChainName.SEPOLIA:
        case src_1.ChainId.SEPOLIA:
            jsonRpcUrl = process.env.SEPOLIA_RPC;
            break;
        case src_1.HardhatChainName.AEVO_TESTNET:
        case src_1.ChainId.AEVO_TESTNET:
            jsonRpcUrl = process.env.AEVO_TESTNET_RPC;
            break;
        case src_1.HardhatChainName.AEVO:
        case src_1.ChainId.AEVO:
            jsonRpcUrl = process.env.AEVO_RPC;
            break;
        case src_1.HardhatChainName.LYRA_TESTNET:
        case src_1.ChainId.LYRA_TESTNET:
            jsonRpcUrl = process.env.LYRA_TESTNET_RPC;
            break;
        case src_1.HardhatChainName.LYRA:
        case src_1.ChainId.LYRA:
            jsonRpcUrl = process.env.LYRA_RPC;
            break;
        case src_1.HardhatChainName.XAI_TESTNET:
        case src_1.ChainId.XAI_TESTNET:
            jsonRpcUrl = process.env.XAI_TESTNET_RPC;
            break;
        case src_1.HardhatChainName.CDK_TESTNET:
        case src_1.ChainId.CDK_TESTNET:
            jsonRpcUrl = process.env.CDK_TESTNET_RPC;
            break;
        case src_1.HardhatChainName.SX_NETWORK_TESTNET:
        case src_1.ChainId.SX_NETWORK_TESTNET:
            jsonRpcUrl = process.env.SX_NETWORK_TESTNET_RPC;
            break;
        case src_1.HardhatChainName.SX_NETWORK:
        case src_1.ChainId.SX_NETWORK:
            jsonRpcUrl = process.env.SX_NETWORK_RPC;
            break;
        case src_1.HardhatChainName.MODE_TESTNET:
        case src_1.ChainId.MODE_TESTNET:
            jsonRpcUrl = process.env.MODE_TESTNET_RPC;
            break;
        case src_1.HardhatChainName.VICTION_TESTNET:
        case src_1.ChainId.VICTION_TESTNET:
            jsonRpcUrl = process.env.VICTION_TESTNET_RPC;
            break;
        case src_1.HardhatChainName.BASE:
        case src_1.ChainId.BASE:
            jsonRpcUrl = process.env.BASE_RPC;
            break;
        case src_1.HardhatChainName.MODE:
        case src_1.ChainId.MODE:
            jsonRpcUrl = process.env.MODE_RPC;
            break;
        case src_1.HardhatChainName.ANCIENT8_TESTNET:
        case src_1.ChainId.ANCIENT8_TESTNET:
            jsonRpcUrl = process.env.ANCIENT8_TESTNET_RPC;
            break;
        case src_1.HardhatChainName.ANCIENT8_TESTNET2:
        case src_1.ChainId.ANCIENT8_TESTNET2:
            jsonRpcUrl = process.env.ANCIENT8_TESTNET2_RPC;
            break;
        case src_1.HardhatChainName.HOOK_TESTNET:
        case src_1.ChainId.HOOK_TESTNET:
            jsonRpcUrl = process.env.HOOK_TESTNET_RPC;
            break;
        case src_1.HardhatChainName.HOOK:
        case src_1.ChainId.HOOK:
            jsonRpcUrl = process.env.HOOK_RPC;
            break;
        case src_1.HardhatChainName.PARALLEL:
        case src_1.ChainId.PARALLEL:
            jsonRpcUrl = process.env.PARALLEL_RPC;
            break;
        case src_1.HardhatChainName.MANTLE:
        case src_1.ChainId.MANTLE:
            jsonRpcUrl = process.env.MANTLE_RPC;
            break;
        case src_1.HardhatChainName.REYA_CRONOS:
        case src_1.ChainId.REYA_CRONOS:
            jsonRpcUrl = process.env.REYA_CRONOS_RPC;
            break;
        case src_1.HardhatChainName.REYA:
        case src_1.ChainId.REYA:
            jsonRpcUrl = process.env.REYA_RPC;
            break;
        case src_1.HardhatChainName.SYNDR_SEPOLIA_L3:
        case src_1.ChainId.SYNDR_SEPOLIA_L3:
            jsonRpcUrl = process.env.SYNDR_SEPOLIA_L3_RPC;
            break;
        case src_1.HardhatChainName.POLYNOMIAL_TESTNET:
        case src_1.ChainId.POLYNOMIAL_TESTNET:
            jsonRpcUrl = process.env.POLYNOMIAL_TESTNET_RPC;
            break;
        case src_1.HardhatChainName.HARDHAT:
        case src_1.ChainId.HARDHAT:
            jsonRpcUrl = "http://127.0.0.1:8545/";
            break;
        case src_1.HardhatChainName.OPTIMISM_SEPOLIA:
        case src_1.ChainId.OPTIMISM_SEPOLIA:
            jsonRpcUrl = process.env.OPTIMISM_SEPOLIA_RPC;
            break;
        case src_1.HardhatChainName.ARBITRUM_SEPOLIA:
        case src_1.ChainId.ARBITRUM_SEPOLIA:
            jsonRpcUrl = process.env.ARBITRUM_SEPOLIA_RPC;
            break;
        case src_1.HardhatChainName.KINTO:
        case src_1.ChainId.KINTO:
            jsonRpcUrl = process.env.KINTO_RPC;
            break;
        default:
            if (process.env.NEW_RPC) {
                jsonRpcUrl = process.env.NEW_RPC;
            }
            else
                throw new Error(`JSON RPC URL not found for ${chain}!!`);
    }
    return jsonRpcUrl;
}
exports.getJsonRpcUrl = getJsonRpcUrl;
const getProviderFromChainName = (hardhatChainName) => {
    const jsonRpcUrl = getJsonRpcUrl(hardhatChainName);
    return new ethers_1.ethers.providers.StaticJsonRpcProvider(jsonRpcUrl);
};
const getProviderFromChainSlug = (chainSlug) => {
    return getProviderFromChainName(src_1.ChainSlugToKey[chainSlug]);
};
exports.getProviderFromChainSlug = getProviderFromChainSlug;
