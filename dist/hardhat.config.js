"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("@typechain/hardhat");
require("hardhat-preprocessor");
require("hardhat-deploy");
require("hardhat-abi-exporter");
require("hardhat-change-network");
const dotenv_1 = require("dotenv");
const path_1 = require("path");
const fs_1 = __importDefault(require("fs"));
require("./tasks/accounts");
const networks_1 = require("./scripts/constants/networks");
const src_1 = require("./src");
const dotenvConfigPath = process.env.DOTENV_CONFIG_PATH || "./.env";
(0, dotenv_1.config)({ path: (0, path_1.resolve)(__dirname, dotenvConfigPath) });
const isProduction = process.env.NODE_ENV === "production";
// Ensure that we have all the environment variables we need.
// TODO: fix it for setup scripts
if (!process.env.SOCKET_SIGNER_KEY)
    throw new Error("No private key found");
const privateKey = process.env
    .SOCKET_SIGNER_KEY;
function getChainConfig(chainId) {
    return {
        accounts: [`0x${privateKey}`],
        chainId,
        url: (0, networks_1.getJsonRpcUrl)(chainId),
    };
}
function getRemappings() {
    return fs_1.default
        .readFileSync("remappings.txt", "utf8")
        .split("\n")
        .filter(Boolean) // remove empty lines
        .map((line) => line.trim().split("="));
}
let liveNetworks = {};
if (isProduction) {
    liveNetworks = {
        [src_1.HardhatChainName.ARBITRUM_GOERLI]: getChainConfig(src_1.ChainId.ARBITRUM_GOERLI),
        [src_1.HardhatChainName.OPTIMISM_GOERLI]: getChainConfig(src_1.ChainId.OPTIMISM_GOERLI),
        [src_1.HardhatChainName.ARBITRUM_SEPOLIA]: getChainConfig(src_1.ChainId.ARBITRUM_SEPOLIA),
        [src_1.HardhatChainName.OPTIMISM_SEPOLIA]: getChainConfig(src_1.ChainId.OPTIMISM_SEPOLIA),
        [src_1.HardhatChainName.POLYGON_MAINNET]: getChainConfig(src_1.ChainId.POLYGON_MAINNET),
        [src_1.HardhatChainName.ARBITRUM]: getChainConfig(src_1.ChainId.ARBITRUM),
        [src_1.HardhatChainName.BSC]: getChainConfig(src_1.ChainId.BSC),
        [src_1.HardhatChainName.GOERLI]: getChainConfig(src_1.ChainId.GOERLI),
        [src_1.HardhatChainName.MAINNET]: getChainConfig(src_1.ChainId.MAINNET),
        [src_1.HardhatChainName.OPTIMISM]: getChainConfig(src_1.ChainId.OPTIMISM),
        [src_1.HardhatChainName.POLYGON_MUMBAI]: getChainConfig(src_1.ChainId.POLYGON_MUMBAI),
        [src_1.HardhatChainName.BSC_TESTNET]: getChainConfig(src_1.ChainId.BSC_TESTNET),
        [src_1.HardhatChainName.SEPOLIA]: getChainConfig(src_1.ChainId.SEPOLIA),
        [src_1.HardhatChainName.AEVO_TESTNET]: getChainConfig(src_1.ChainId.AEVO_TESTNET),
        [src_1.HardhatChainName.AEVO]: getChainConfig(src_1.ChainId.AEVO),
        [src_1.HardhatChainName.LYRA_TESTNET]: getChainConfig(src_1.ChainId.LYRA_TESTNET),
        [src_1.HardhatChainName.LYRA]: getChainConfig(src_1.ChainId.LYRA),
        [src_1.HardhatChainName.XAI_TESTNET]: getChainConfig(src_1.ChainId.XAI_TESTNET),
        [src_1.HardhatChainName.SX_NETWORK_TESTNET]: getChainConfig(src_1.ChainId.SX_NETWORK_TESTNET),
        [src_1.HardhatChainName.SX_NETWORK]: getChainConfig(src_1.ChainId.SX_NETWORK),
        [src_1.HardhatChainName.MODE_TESTNET]: getChainConfig(src_1.ChainId.MODE_TESTNET),
        [src_1.HardhatChainName.VICTION_TESTNET]: getChainConfig(src_1.ChainId.VICTION_TESTNET),
        [src_1.HardhatChainName.BASE]: getChainConfig(src_1.ChainId.BASE),
        [src_1.HardhatChainName.MODE]: getChainConfig(src_1.ChainId.MODE),
        [src_1.HardhatChainName.ANCIENT8_TESTNET]: getChainConfig(src_1.ChainId.ANCIENT8_TESTNET),
        [src_1.HardhatChainName.ANCIENT8_TESTNET2]: getChainConfig(src_1.ChainId.ANCIENT8_TESTNET2),
        [src_1.HardhatChainName.HOOK_TESTNET]: getChainConfig(src_1.ChainId.HOOK_TESTNET),
        [src_1.HardhatChainName.HOOK]: getChainConfig(src_1.ChainId.HOOK),
        [src_1.HardhatChainName.PARALLEL]: getChainConfig(src_1.ChainId.PARALLEL),
        [src_1.HardhatChainName.MANTLE]: getChainConfig(src_1.ChainId.MANTLE),
        [src_1.HardhatChainName.REYA_CRONOS]: getChainConfig(src_1.ChainId.REYA_CRONOS),
        [src_1.HardhatChainName.REYA]: getChainConfig(src_1.ChainId.REYA),
        [src_1.HardhatChainName.SYNDR_SEPOLIA_L3]: getChainConfig(src_1.ChainId.SYNDR_SEPOLIA_L3),
        [src_1.HardhatChainName.POLYNOMIAL_TESTNET]: getChainConfig(src_1.ChainId.POLYNOMIAL_TESTNET),
        [src_1.HardhatChainName.KINTO]: getChainConfig(src_1.ChainId.KINTO),
    };
}
const config = {
    defaultNetwork: "hardhat",
    abiExporter: {
        path: "artifacts/abi",
        flat: true,
    },
    etherscan: {
        apiKey: {
            arbitrumOne: process.env.ARBISCAN_API_KEY || "",
            arbitrumTestnet: process.env.ARBISCAN_API_KEY || "",
            avalanche: process.env.SNOWTRACE_API_KEY || "",
            bsc: process.env.BSCSCAN_API_KEY || "",
            bscTestnet: process.env.BSCSCAN_API_KEY || "",
            goerli: process.env.ETHERSCAN_API_KEY || "",
            mainnet: process.env.ETHERSCAN_API_KEY || "",
            sepolia: process.env.ETHERSCAN_API_KEY || "",
            optimisticEthereum: process.env.OPTIMISM_API_KEY || "",
            optimisticTestnet: process.env.OPTIMISM_API_KEY || "",
            polygon: process.env.POLYGONSCAN_API_KEY || "",
            polygonMumbai: process.env.POLYGONSCAN_API_KEY || "",
            aevoTestnet: process.env.AEVO_API_KEY || "",
            lyraTestnet: process.env.LYRA_API_KEY || "",
            lyra: process.env.LYRA_API_KEY || "",
            xaiTestnet: process.env.XAI_API_KEY || "",
            sxn: process.env.SX_NETWORK_API_KEY || "",
            modeTestnet: process.env.MODE_API_KEY || "",
            victionTestnet: process.env.VICTION_API_KEY || "",
            base: process.env.BASESCAN_API_KEY || "",
            mode: process.env.MODE_API_KEY || "",
            ancient8Testnet: process.env.ANCIENT8_API_KEY || "",
            ancient8Testnet2: process.env.ANCIENT8_API_KEY || "",
            hookTestnet: process.env.HOOK_API_KEY || "",
            hook: process.env.HOOK_API_KEY || "",
            parallelTestnet: process.env.PARALLEL_API_KEY || "",
            mantle: process.env.MANTLE_API_KEY || "",
            reya: process.env.REYA_API_KEY || "",
            syndrSepoliaL3: process.env.SYNDR_API_KEY || "",
            kinto: process.env.KINTO_API_KEY || "",
        },
        customChains: [
            {
                network: "optimisticTestnet",
                chainId: src_1.ChainId.OPTIMISM_SEPOLIA,
                urls: {
                    apiURL: "https://api-sepolia-optimistic.etherscan.io/api",
                    browserURL: "https://sepolia-optimism.etherscan.io/",
                },
            },
            {
                network: "arbitrumTestnet",
                chainId: src_1.ChainId.ARBITRUM_SEPOLIA,
                urls: {
                    apiURL: "https://api-sepolia.arbiscan.io/api",
                    browserURL: "https://sepolia.arbiscan.io/",
                },
            },
            {
                network: "base",
                chainId: src_1.ChainId.BASE,
                urls: {
                    apiURL: "https://api.basescan.org/api",
                    browserURL: "https://basescan.org/",
                },
            },
            {
                network: "kinto",
                chainId: src_1.ChainId.KINTO,
                urls: {
                    apiURL: "https://explorer.kinto.xyz/api",
                    browserURL: "https://explorer.kinto.xyz",
                },
            },
        ],
    },
    networks: {
        hardhat: {
            chainId: src_1.hardhatChainNameToSlug[src_1.HardhatChainName.HARDHAT],
        },
        ...liveNetworks,
    },
    paths: {
        sources: "./contracts",
        cache: "./cache_hardhat",
        artifacts: "./artifacts",
        tests: "./test",
    },
    // This fully resolves paths for imports in the ./lib directory for Hardhat
    preprocess: {
        eachLine: (hre) => ({
            transform: (line) => {
                if (line.match(/^\s*import /i)) {
                    getRemappings().forEach(([find, replace]) => {
                        if (line.match(find)) {
                            line = line.replace(find, replace);
                        }
                    });
                }
                return line;
            },
        }),
    },
    solidity: {
        version: "0.8.19",
        settings: {
            optimizer: {
                enabled: true,
                runs: 999999,
            },
            // viaIR: true
        },
    },
};
exports.default = config;
