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
import type {
  HardhatNetworkAccountUserConfig,
  NetworkUserConfig,
} from "hardhat/types";
import { resolve } from "path";
import fs from "fs";

import "./tasks/accounts";
import { getJsonRpcUrl } from "./scripts/constants/networks";
import { ChainKey, chainKeyToSlug } from "./src";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });
const isProduction = process.env.NODE_ENV === "production";

// Ensure that we have all the environment variables we need.
if (!process.env.SOCKET_SIGNER_KEY) throw new Error("No private key found");
const privateKey: HardhatNetworkAccountUserConfig = process.env
  .SOCKET_SIGNER_KEY as unknown as HardhatNetworkAccountUserConfig;

function getChainConfig(chain: keyof typeof chainKeyToSlug): NetworkUserConfig {
  return {
    accounts: [`0x${privateKey}`],
    chainId: chainKeyToSlug[chain],
    url: getJsonRpcUrl(chain),
  };
}

function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean) // remove empty lines
    .map((line) => line.trim().split("="));
}

let liveNetworks = {};
if (isProduction) {
  liveNetworks = {
    [ChainKey.ARBITRUM_GOERLI]: getChainConfig(ChainKey.ARBITRUM_GOERLI),
    [ChainKey.OPTIMISM_GOERLI]: getChainConfig(ChainKey.OPTIMISM_GOERLI),
    [ChainKey.POLYGON_MAINNET]: getChainConfig(ChainKey.POLYGON_MAINNET),
    [ChainKey.ARBITRUM]: getChainConfig(ChainKey.ARBITRUM),
    [ChainKey.AVALANCHE]: getChainConfig(ChainKey.AVALANCHE),
    [ChainKey.BSC]: getChainConfig(ChainKey.BSC),
    [ChainKey.GOERLI]: getChainConfig(ChainKey.GOERLI),
    [ChainKey.MAINNET]: getChainConfig(ChainKey.MAINNET),
    [ChainKey.OPTIMISM]: getChainConfig(ChainKey.OPTIMISM),
    [ChainKey.POLYGON_MUMBAI]: getChainConfig(ChainKey.POLYGON_MUMBAI),
    [ChainKey.BSC_TESTNET]: getChainConfig(ChainKey.BSC_TESTNET),
    [ChainKey.SEPOLIA]: getChainConfig(ChainKey.SEPOLIA),
    [ChainKey.AEVO_TESTNET]: getChainConfig(ChainKey.AEVO_TESTNET),
    [ChainKey.AEVO]: getChainConfig(ChainKey.AEVO),
    [ChainKey.LYRA_TESTNET]: getChainConfig(ChainKey.LYRA_TESTNET),
  };
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
    },
    customChains: [
      {
        network: "optimisticTestnet",
        chainId: chainKeyToSlug[ChainKey.OPTIMISM_GOERLI],
        urls: {
          apiURL: "https://api-goerli-optimistic.etherscan.io/api",
          browserURL: "https://goerli-optimism.etherscan.io/",
        },
      },
      {
        network: "arbitrumTestnet",
        chainId: chainKeyToSlug[ChainKey.ARBITRUM_GOERLI],
        urls: {
          apiURL: "https://api-goerli.arbiscan.io/api",
          browserURL: "https://goerli.arbiscan.io/",
        },
      },
      {
        network: "aevoTestnet",
        chainId: chainKeyToSlug[ChainKey.AEVO_TESTNET],
        urls: {
          apiURL: "",
          browserURL: "https://explorer-testnet.aevo.xyz/",
        },
      },
      {
        network: "aevo",
        chainId: chainKeyToSlug[ChainKey.AEVO],
        urls: {
          apiURL: "",
          browserURL: "https://explorer-testnet.aevo.xyz/",
        },
      },
    ],
  },
  networks: {
    hardhat: {
      chainId: chainKeyToSlug.hardhat,
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
