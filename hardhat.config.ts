import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";
import "hardhat-preprocessor";
import "hardhat-deploy";
import "hardhat-abi-exporter";
import "hardhat-change-network";

import { config as dotenvConfig } from "dotenv";
import type { HardhatUserConfig } from "hardhat/config";
import { resolve } from "path";
import fs from "fs";

import "./tasks/accounts";
import {
  ChainId,
  ChainSlug,
  HardhatChainName,
  hardhatChainNameToSlug,
} from "./src";
import { HardhatNetworkAccountUserConfig } from "hardhat/types";
import { getChainConfig } from "./scripts/deploy/utils";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });
const isProduction = process.env.NODE_ENV === "production";

// Ensure that we have all the environment variables we need.
// TODO: fix it for setup scripts
// if (!process.env.SOCKET_SIGNER_KEY) throw new Error("No private key found");
const privateKey: HardhatNetworkAccountUserConfig = process.env
  .SOCKET_SIGNER_KEY as unknown as HardhatNetworkAccountUserConfig;

function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean) // remove empty lines
    .map((line) => line.trim().split("="));
}

export const networks = {
  [HardhatChainName.ARBITRUM_GOERLI]: getChainConfig(
    ChainSlug.ARBITRUM_GOERLI,
    privateKey
  ),
  [HardhatChainName.OPTIMISM_GOERLI]: getChainConfig(
    ChainSlug.OPTIMISM_GOERLI,
    privateKey
  ),
  [HardhatChainName.ARBITRUM_SEPOLIA]: getChainConfig(
    ChainSlug.ARBITRUM_SEPOLIA,
    privateKey
  ),
  [HardhatChainName.OPTIMISM_SEPOLIA]: getChainConfig(
    ChainSlug.OPTIMISM_SEPOLIA,
    privateKey
  ),
  [HardhatChainName.POLYGON_MAINNET]: getChainConfig(
    ChainSlug.POLYGON_MAINNET,
    privateKey
  ),
  [HardhatChainName.ARBITRUM]: getChainConfig(ChainSlug.ARBITRUM, privateKey),
  [HardhatChainName.BSC]: getChainConfig(ChainSlug.BSC, privateKey),
  [HardhatChainName.GOERLI]: getChainConfig(ChainSlug.GOERLI, privateKey),
  [HardhatChainName.MAINNET]: getChainConfig(ChainSlug.MAINNET, privateKey),
  [HardhatChainName.OPTIMISM]: getChainConfig(ChainSlug.OPTIMISM, privateKey),
  [HardhatChainName.POLYGON_MUMBAI]: getChainConfig(
    ChainSlug.POLYGON_MUMBAI,
    privateKey
  ),
  [HardhatChainName.SEPOLIA]: getChainConfig(ChainSlug.SEPOLIA, privateKey),
  [HardhatChainName.AEVO_TESTNET]: getChainConfig(
    ChainSlug.AEVO_TESTNET,
    privateKey
  ),
  [HardhatChainName.AEVO]: getChainConfig(ChainSlug.AEVO, privateKey),
  [HardhatChainName.LYRA_TESTNET]: getChainConfig(
    ChainSlug.LYRA_TESTNET,
    privateKey
  ),
  [HardhatChainName.LYRA]: getChainConfig(ChainSlug.LYRA, privateKey),
  [HardhatChainName.XAI_TESTNET]: getChainConfig(
    ChainSlug.XAI_TESTNET,
    privateKey
  ),
  [HardhatChainName.SX_NETWORK_TESTNET]: getChainConfig(
    ChainSlug.SX_NETWORK_TESTNET,
    privateKey
  ),
  [HardhatChainName.SX_NETWORK]: getChainConfig(
    ChainSlug.SX_NETWORK,
    privateKey
  ),
  [HardhatChainName.MODE_TESTNET]: getChainConfig(
    ChainSlug.MODE_TESTNET,
    privateKey
  ),
  [HardhatChainName.VICTION_TESTNET]: getChainConfig(
    ChainSlug.VICTION_TESTNET,
    privateKey
  ),
  [HardhatChainName.BASE]: getChainConfig(ChainSlug.BASE, privateKey),
  [HardhatChainName.MODE]: getChainConfig(ChainSlug.MODE, privateKey),
  [HardhatChainName.ANCIENT8_TESTNET]: getChainConfig(
    ChainSlug.ANCIENT8_TESTNET,
    privateKey
  ),
  [HardhatChainName.ANCIENT8_TESTNET2]: getChainConfig(
    ChainSlug.ANCIENT8_TESTNET2,
    privateKey
  ),
  [HardhatChainName.HOOK_TESTNET]: getChainConfig(
    ChainSlug.HOOK_TESTNET,
    privateKey
  ),
  [HardhatChainName.HOOK]: getChainConfig(ChainSlug.HOOK, privateKey),
  [HardhatChainName.PARALLEL]: getChainConfig(ChainSlug.PARALLEL, privateKey),
  [HardhatChainName.MANTLE]: getChainConfig(ChainSlug.MANTLE, privateKey),
  [HardhatChainName.REYA_CRONOS]: getChainConfig(
    ChainSlug.REYA_CRONOS,
    privateKey
  ),
  [HardhatChainName.REYA]: getChainConfig(ChainSlug.REYA, privateKey),
  [HardhatChainName.SYNDR_SEPOLIA_L3]: getChainConfig(
    ChainSlug.SYNDR_SEPOLIA_L3,
    privateKey
  ),
  [HardhatChainName.POLYNOMIAL_TESTNET]: getChainConfig(
    ChainSlug.POLYNOMIAL_TESTNET,
    privateKey
  ),
  [HardhatChainName.BSC_TESTNET]: getChainConfig(
    ChainSlug.BSC_TESTNET,
    privateKey
  ),
};

let liveNetworks = {};
if (isProduction) {
  liveNetworks = networks;
}

const config: HardhatUserConfig = {
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
    },
    customChains: [
      {
        network: "optimisticTestnet",
        chainId: ChainId.OPTIMISM_SEPOLIA,
        urls: {
          apiURL: "https://api-sepolia-optimistic.etherscan.io/api",
          browserURL: "https://sepolia-optimism.etherscan.io/",
        },
      },
      {
        network: "arbitrumTestnet",
        chainId: ChainId.ARBITRUM_SEPOLIA,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io/",
        },
      },
      {
        network: "base",
        chainId: ChainId.BASE,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org/",
        },
      },
    ],
  },
  networks: {
    hardhat: {
      chainId: hardhatChainNameToSlug[HardhatChainName.HARDHAT],
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
      transform: (line: string) => {
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

export default config;
