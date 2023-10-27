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
import { ChainId, HardhatChainName, hardhatChainNameToSlug } from "./src";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });
const isProduction = process.env.NODE_ENV === "production";

// Ensure that we have all the environment variables we need.
if (!process.env.SOCKET_SIGNER_KEY) throw new Error("No private key found");
const privateKey: HardhatNetworkAccountUserConfig = process.env
  .SOCKET_SIGNER_KEY as unknown as HardhatNetworkAccountUserConfig;

function getChainConfig(chainId: ChainId): NetworkUserConfig {
  return {
    accounts: [`0x${privateKey}`],
    chainId,
    url: getJsonRpcUrl(chainId),
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
    [HardhatChainName.ARBITRUM_GOERLI]: getChainConfig(ChainId.ARBITRUM_GOERLI),
    [HardhatChainName.OPTIMISM_GOERLI]: getChainConfig(ChainId.OPTIMISM_GOERLI),
    [HardhatChainName.POLYGON_MAINNET]: getChainConfig(ChainId.POLYGON_MAINNET),
    [HardhatChainName.ARBITRUM]: getChainConfig(ChainId.ARBITRUM),
    [HardhatChainName.BSC]: getChainConfig(ChainId.BSC),
    [HardhatChainName.GOERLI]: getChainConfig(ChainId.GOERLI),
    [HardhatChainName.MAINNET]: getChainConfig(ChainId.MAINNET),
    [HardhatChainName.OPTIMISM]: getChainConfig(ChainId.OPTIMISM),
    [HardhatChainName.POLYGON_MUMBAI]: getChainConfig(ChainId.POLYGON_MUMBAI),
    [HardhatChainName.BSC_TESTNET]: getChainConfig(ChainId.BSC_TESTNET),
    [HardhatChainName.SEPOLIA]: getChainConfig(ChainId.SEPOLIA),
    [HardhatChainName.AEVO_TESTNET]: getChainConfig(ChainId.AEVO_TESTNET),
    [HardhatChainName.AEVO]: getChainConfig(ChainId.AEVO),
    [HardhatChainName.LYRA_TESTNET]: getChainConfig(ChainId.LYRA_TESTNET),
    [HardhatChainName.XAI_TESTNET]: getChainConfig(ChainId.XAI_TESTNET),
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
      lyraTestnet: process.env.LYRA_API_KEY || "",
      xaiTestnet: process.env.XAI_API_KEY || "",
    },
    customChains: [
      {
        network: "optimisticTestnet",
        chainId: ChainId.OPTIMISM_GOERLI,
        urls: {
          apiURL: "https://api-goerli-optimistic.etherscan.io/api",
          browserURL: "https://goerli-optimism.etherscan.io/",
        },
      },
      {
        network: "arbitrumTestnet",
        chainId: ChainId.ARBITRUM_GOERLI,
        urls: {
          apiURL: "https://api-goerli.arbiscan.io/api",
          browserURL: "https://goerli.arbiscan.io/",
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
