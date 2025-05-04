import "@nomiclabs/hardhat-ethers";
// import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";
import "hardhat-preprocessor";
import "hardhat-deploy";
import "hardhat-abi-exporter";
import "hardhat-change-network";
import "@nomicfoundation/hardhat-verify";
// import "@matterlabs/hardhat-zksync";

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
import {
  ChainId,
  ChainSlug,
  ChainSlugToId,
  HardhatChainName,
  hardhatChainNameToSlug,
} from "./src";

const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: resolve(__dirname, dotenvConfigPath) });
const isProduction = process.env.NODE_ENV === "production";

// Ensure that we have all the environment variables we need.
// TODO: fix it for setup scripts
// if (!process.env.SOCKET_SIGNER_KEY) throw new Error("No private key found");
const privateKey: HardhatNetworkAccountUserConfig = process.env
  .SOCKET_SIGNER_KEY as unknown as HardhatNetworkAccountUserConfig;

function getChainConfig(chainSlug: ChainSlug): NetworkUserConfig {
  return {
    accounts: [`0x${privateKey}`],
    chainId: ChainSlugToId[chainSlug],
    url: getJsonRpcUrl(chainSlug),
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
    [HardhatChainName.ARBITRUM_SEPOLIA]: getChainConfig(
      ChainSlug.ARBITRUM_SEPOLIA
    ),
    [HardhatChainName.OPTIMISM_SEPOLIA]: getChainConfig(
      ChainSlug.OPTIMISM_SEPOLIA
    ),
    [HardhatChainName.POLYGON_MAINNET]: getChainConfig(
      ChainSlug.POLYGON_MAINNET
    ),
    [HardhatChainName.ARBITRUM]: getChainConfig(ChainSlug.ARBITRUM),
    [HardhatChainName.BSC]: getChainConfig(ChainSlug.BSC),
    [HardhatChainName.GOERLI]: getChainConfig(ChainSlug.GOERLI),
    [HardhatChainName.MAINNET]: getChainConfig(ChainSlug.MAINNET),
    [HardhatChainName.OPTIMISM]: getChainConfig(ChainSlug.OPTIMISM),
    [HardhatChainName.SEPOLIA]: getChainConfig(ChainSlug.SEPOLIA),
    [HardhatChainName.AEVO_TESTNET]: getChainConfig(ChainSlug.AEVO_TESTNET),
    [HardhatChainName.AEVO]: getChainConfig(ChainSlug.AEVO),
    [HardhatChainName.LYRA_TESTNET]: getChainConfig(ChainSlug.LYRA_TESTNET),
    [HardhatChainName.LYRA]: getChainConfig(ChainSlug.LYRA),
    [HardhatChainName.XAI_TESTNET]: getChainConfig(ChainSlug.XAI_TESTNET),
    [HardhatChainName.SX_NETWORK_TESTNET]: getChainConfig(
      ChainSlug.SX_NETWORK_TESTNET
    ),
    [HardhatChainName.SX_NETWORK]: getChainConfig(ChainSlug.SX_NETWORK),
    [HardhatChainName.MODE_TESTNET]: getChainConfig(ChainSlug.MODE_TESTNET),
    [HardhatChainName.VICTION_TESTNET]: getChainConfig(
      ChainSlug.VICTION_TESTNET
    ),
    [HardhatChainName.BASE]: getChainConfig(ChainSlug.BASE),
    [HardhatChainName.MODE]: getChainConfig(ChainSlug.MODE),
    [HardhatChainName.ANCIENT8_TESTNET]: getChainConfig(
      ChainSlug.ANCIENT8_TESTNET
    ),
    [HardhatChainName.ANCIENT8_TESTNET2]: getChainConfig(
      ChainSlug.ANCIENT8_TESTNET2
    ),
    [HardhatChainName.PARALLEL]: getChainConfig(ChainSlug.PARALLEL),
    [HardhatChainName.MANTLE]: getChainConfig(ChainSlug.MANTLE),
    [HardhatChainName.REYA_CRONOS]: getChainConfig(ChainSlug.REYA_CRONOS),
    [HardhatChainName.REYA]: getChainConfig(ChainSlug.REYA),
    [HardhatChainName.SYNDR_SEPOLIA_L3]: getChainConfig(
      ChainSlug.SYNDR_SEPOLIA_L3
    ),
    [HardhatChainName.POLYNOMIAL_TESTNET]: getChainConfig(
      ChainSlug.POLYNOMIAL_TESTNET
    ),
    [HardhatChainName.BOB]: getChainConfig(ChainSlug.BOB),
    [HardhatChainName.KINTO]: getChainConfig(ChainSlug.KINTO),
    [HardhatChainName.KINTO_DEVNET]: getChainConfig(ChainSlug.KINTO_DEVNET),
    [HardhatChainName.SIPHER_FUNKI_TESTNET]: getChainConfig(
      ChainSlug.SIPHER_FUNKI_TESTNET
    ),
    [HardhatChainName.WINR]: getChainConfig(ChainSlug.WINR),
    [HardhatChainName.POLYNOMIAL]: getChainConfig(ChainSlug.POLYNOMIAL),
    [HardhatChainName.SYNDR]: getChainConfig(ChainSlug.SYNDR),
    [HardhatChainName.BLAST]: getChainConfig(ChainSlug.BLAST),
    [HardhatChainName.NEOX_TESTNET]: getChainConfig(ChainSlug.NEOX_TESTNET),
    [HardhatChainName.GNOSIS]: getChainConfig(ChainSlug.GNOSIS),
    [HardhatChainName.LINEA]: getChainConfig(ChainSlug.LINEA),
    [HardhatChainName.ZKEVM]: getChainConfig(ChainSlug.ZKEVM),
    [HardhatChainName.AVALANCHE]: getChainConfig(ChainSlug.AVALANCHE),
    [HardhatChainName.MANTA_PACIFIC]: getChainConfig(ChainSlug.MANTA_PACIFIC),
    [HardhatChainName.OPBNB]: getChainConfig(ChainSlug.OPBNB),
    [HardhatChainName.GEIST]: getChainConfig(ChainSlug.GEIST),
    [HardhatChainName.SONIC]: getChainConfig(ChainSlug.SONIC),
    [HardhatChainName.BERA]: getChainConfig(ChainSlug.BERA),
    [HardhatChainName.B3]: getChainConfig(ChainSlug.B3),
    [HardhatChainName.UNICHAIN]: getChainConfig(ChainSlug.UNICHAIN),
    [HardhatChainName.SCROLL]: getChainConfig(ChainSlug.SCROLL),
    [HardhatChainName.SONEIUM]: getChainConfig(ChainSlug.SONEIUM),
    [HardhatChainName.SWELLCHAIN]: getChainConfig(ChainSlug.SWELLCHAIN),
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
      mode: process.env.MODE_API_KEY || "none",
      ancient8Testnet: process.env.ANCIENT8_API_KEY || "",
      ancient8Testnet2: process.env.ANCIENT8_API_KEY || "",
      parallelTestnet: process.env.PARALLEL_API_KEY || "",
      mantle: process.env.MANTLE_API_KEY || "",
      reya: process.env.REYA_API_KEY || "",
      syndrSepoliaL3: process.env.SYNDR_API_KEY || "",
      kinto: process.env.KINTO_API_KEY || "",
      kinto_devnet: process.env.KINTO_DEVNET_API_KEY || "",
      sipher_funki_testnet: "none",
      winr: "none",
      reya_cronos: "none",
      polynomial: "none",
      syndr: "none",
      blast: process.env.BLASTSCAN_API_KEY || "",
      neox_testnet: "none",
      gnosis: process.env.GNOSISSCAN_API_KEY || "",
      linea: process.env.LINEASCAN_API_KEY || "",
      zkevm: process.env.ZKEVM_API_KEY || "",
      avalanche: process.env.SNOWTRACE_API_KEY || "",
      manta_pacific: process.env.MANTA_PACIFIC_API_KEY || "none",
      opbnb: process.env.OPBNB_API_KEY || "none",
      geist: process.env.GEIST_API_KEY || "none",
      sonic: process.env.SONICSCAN_API_KEY || "",
      berascan: process.env.BERASCAN_API_KEY || "",
      b3: process.env.B3_API_KEY || "none",
      unichain: process.env.UNICHAIN_API_KEY || "none",
      scroll: process.env.SCROLLSCAN_API_KEY || "",
      soneium: process.env.SONEIUM_API_KEY || "none",
      swellchain: process.env.SWELLCHAIN_API_KEY || "none",
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
      {
        network: "kinto",
        chainId: ChainId.KINTO,
        urls: {
          apiURL: "https://explorer.kinto.xyz/api",
          browserURL: "https://explorer.kinto.xyz",
        },
      },
      {
        network: "sipher_funki_testnet",
        chainId: ChainId.SIPHER_FUNKI_TESTNET,
        urls: {
          apiURL: "https://sepolia-sandbox.funkichain.com/api",
          browserURL: "https://sepolia-sandbox.funkichain.com",
        },
      },
      {
        network: "winr",
        chainId: ChainId.WINR,
        urls: {
          apiURL: "https://explorerl2new-winr-mainnet-0.t.conduit.xyz/api",
          browserURL: "https://explorerl2new-winr-mainnet-0.t.conduit.xyz",
        },
      },
      {
        network: "reya_cronos",
        chainId: ChainId.REYA_CRONOS,
        urls: {
          apiURL: "https://reya-cronos.blockscout.com//api",
          browserURL: "https://reya-cronos.blockscout.com/",
        },
      },
      {
        network: "polynomial",
        chainId: ChainId.POLYNOMIAL,
        urls: {
          apiURL: "https://polynomialscan.io/api",
          browserURL: "https://polynomialscan.io",
        },
      },
      {
        network: "syndr",
        chainId: ChainId.SYNDR,
        urls: {
          apiURL: "https://explorer.syndr.com/api",
          browserURL: "https://explorer.syndr.com",
        },
      },
      {
        network: "blast",
        chainId: ChainId.BLAST,
        urls: {
          apiURL: "https://api.blastscan.io/api",
          browserURL: "https://blastscan.io",
        },
      },
      {
        network: "mode",
        chainId: ChainId.MODE,
        urls: {
          apiURL: "https://explorer.mode.network/api",
          browserURL: "https://explorer.mode.network",
        },
      },
      {
        network: "neox_testnet",
        chainId: ChainId.NEOX_TESTNET,
        urls: {
          apiURL: "https://xt3scan.ngd.network/api",
          browserURL: "https://xt3scan.ngd.network",
        },
      },
      {
        network: "gnosis",
        chainId: ChainId.GNOSIS,
        urls: {
          apiURL: "https://api.gnosisscan.io/api",
          browserURL: "https://gnosisscan.io",
        },
      },
      {
        network: "linea",
        chainId: ChainId.LINEA,
        urls: {
          apiURL: "https://api.lineascan.build/api",
          browserURL: "https://lineascan.build",
        },
      },
      {
        network: "zkevm",
        chainId: ChainId.ZKEVM,
        urls: {
          apiURL: "https://api-zkevm.polygonscan.com/api",
          browserURL: "https://zkevm.polygonscan.com/",
        },
      },
      {
        network: "avalanche",
        chainId: ChainId.AVALANCHE,
        urls: {
          apiURL: "https://api.snowtrace.io/api",
          browserURL: "https://snowtrace.io/",
        },
      },
      {
        network: "manta_pacific",
        chainId: ChainId.MANTA_PACIFIC,
        urls: {
          apiURL: "https://pacific-explorer.manta.network/api",
          browserURL: "https://pacific-explorer.manta.network/",
        },
      },
      {
        network: "opbnb",
        chainId: ChainId.OPBNB,
        urls: {
          apiURL: "https://api-opbnb.bscscan.com/api",
          browserURL: "https://opbnb.bscscan.com/",
        },
      },
      {
        network: "geist",
        chainId: ChainId.GEIST,
        urls: {
          apiURL: "https://geist-mainnet.explorer.alchemy.com/api",
          browserURL: "https://geist-mainnet.explorer.alchemy.com/",
        },
      },
      {
        network: "sonic",
        chainId: ChainId.SONIC,
        urls: {
          apiURL: "https://api.sonicscan.org/api",
          browserURL: "https://sonicscan.org/",
        },
      },
      {
        network: "berascan",
        chainId: ChainId.BERA,
        urls: {
          apiURL: "https://api.berascan.com/api",
          browserURL: "https://berascan.com/",
        },
      },
      {
        network: "b3",
        chainId: ChainId.B3,
        urls: {
          apiURL: "https://explorer.b3.fun/api",
          browserURL: "https://explorer.b3.fun/",
        },
      },
      {
        network: "unichain",
        chainId: ChainId.UNICHAIN,
        urls: {
          apiURL: "https://unichain.blockscout.com/api",
          browserURL: "https://unichain.blockscout.com/",
        },
      },
      {
        network: "scroll",
        chainId: ChainId.SCROLL,
        urls: {
          apiURL: "https://api.scrollscan.com/api",
          browserURL: "https://scrollscan.com/",
        },
      },
      {
        network: "soneium",
        chainId: ChainId.SONEIUM,
        urls: {
          apiURL: "https://soneium.blockscout.com/api",
          browserURL: "https://soneium.blockscout.com/",
        },
      },
      {
        network: "swellchain",
        chainId: ChainId.SWELLCHAIN,
        urls: {
          apiURL: "https://explorer.swellnetwork.io/api",
          browserURL: "https://explorer.swellnetwork.io/",
        },
      },
    ],
  },
  networks: {
    hardhat: {
      chainId: hardhatChainNameToSlug[HardhatChainName.HARDHAT],
    },
    ...liveNetworks,
    zeroTestnet: {
      url: process.env.ZERO_SEPOLIA_RPC || "",
      zksync: true,
      ethNetwork: "sepolia",
      verifyURL: "https://zerion-testnet-proofs.explorer.caldera.xyz/api",
    },
    zero: {
      url: process.env.ZERO_RPC || "",
      zksync: true,
      ethNetwork: "mainnet",
      verifyURL: "https://zero-network.calderaexplorer.xyz/api",
    },
    zksync: {
      url: process.env.ZKSYNC_RPC || "",
      zksync: true,
      ethNetwork: "mainnet",
      verifyURL: "",
    },
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
  zksolc: {
    version: "latest", // Uses latest available in https://github.com/matter-labs/zksolc-bin
    settings: {},
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
