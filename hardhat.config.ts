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
// TODO: fix it for setup scripts
// if (!process.env.SOCKET_SIGNER_KEY) throw new Error("No private key found");
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
    [HardhatChainName.ARBITRUM_SEPOLIA]: getChainConfig(
      ChainId.ARBITRUM_SEPOLIA
    ),
    [HardhatChainName.OPTIMISM_SEPOLIA]: getChainConfig(
      ChainId.OPTIMISM_SEPOLIA
    ),
    [HardhatChainName.POLYGON_MAINNET]: getChainConfig(ChainId.POLYGON_MAINNET),
    [HardhatChainName.ARBITRUM]: getChainConfig(ChainId.ARBITRUM),
    [HardhatChainName.BSC]: getChainConfig(ChainId.BSC),
    [HardhatChainName.GOERLI]: getChainConfig(ChainId.GOERLI),
    [HardhatChainName.MAINNET]: getChainConfig(ChainId.MAINNET),
    [HardhatChainName.OPTIMISM]: getChainConfig(ChainId.OPTIMISM),
    [HardhatChainName.BSC_TESTNET]: getChainConfig(ChainId.BSC_TESTNET),
    [HardhatChainName.SEPOLIA]: getChainConfig(ChainId.SEPOLIA),
    [HardhatChainName.AEVO_TESTNET]: getChainConfig(ChainId.AEVO_TESTNET),
    [HardhatChainName.AEVO]: getChainConfig(ChainId.AEVO),
    [HardhatChainName.LYRA_TESTNET]: getChainConfig(ChainId.LYRA_TESTNET),
    [HardhatChainName.LYRA]: getChainConfig(ChainId.LYRA),
    [HardhatChainName.XAI_TESTNET]: getChainConfig(ChainId.XAI_TESTNET),
    [HardhatChainName.SX_NETWORK_TESTNET]: getChainConfig(
      ChainId.SX_NETWORK_TESTNET
    ),
    [HardhatChainName.SX_NETWORK]: getChainConfig(ChainId.SX_NETWORK),
    [HardhatChainName.MODE_TESTNET]: getChainConfig(ChainId.MODE_TESTNET),
    [HardhatChainName.VICTION_TESTNET]: getChainConfig(ChainId.VICTION_TESTNET),
    [HardhatChainName.BASE]: getChainConfig(ChainId.BASE),
    [HardhatChainName.MODE]: getChainConfig(ChainId.MODE),
    [HardhatChainName.ANCIENT8_TESTNET]: getChainConfig(
      ChainId.ANCIENT8_TESTNET
    ),
    [HardhatChainName.ANCIENT8_TESTNET2]: getChainConfig(
      ChainId.ANCIENT8_TESTNET2
    ),
    [HardhatChainName.HOOK_TESTNET]: getChainConfig(ChainId.HOOK_TESTNET),
    [HardhatChainName.HOOK]: getChainConfig(ChainId.HOOK),
    [HardhatChainName.PARALLEL]: getChainConfig(ChainId.PARALLEL),
    [HardhatChainName.MANTLE]: getChainConfig(ChainId.MANTLE),
    [HardhatChainName.REYA_CRONOS]: getChainConfig(ChainId.REYA_CRONOS),
    [HardhatChainName.REYA]: getChainConfig(ChainId.REYA),
    [HardhatChainName.SYNDR_SEPOLIA_L3]: getChainConfig(
      ChainId.SYNDR_SEPOLIA_L3
    ),
    [HardhatChainName.POLYNOMIAL_TESTNET]: getChainConfig(
      ChainId.POLYNOMIAL_TESTNET
    ),
    [HardhatChainName.BOB]: getChainConfig(ChainId.BOB),
    [HardhatChainName.KINTO]: getChainConfig(ChainId.KINTO),
    [HardhatChainName.KINTO_DEVNET]: getChainConfig(ChainId.KINTO_DEVNET),
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
      kinto_devnet: process.env.KINTO_DEVNET_API_KEY || "",
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
      {
        network: "kinto_devnet",
        chainId: ChainId.KINTO_DEVNET,
        urls: {
          apiURL: "https://kinto-upgrade-dev-2.explorer.caldera.xyz/api",
          browserURL: "https://kinto-upgrade-dev-2.explorer.caldera.xyz",
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
