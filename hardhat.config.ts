import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers"
import "@typechain/hardhat";
import "hardhat-preprocessor";
import "hardhat-deploy";

import fs from "fs";
import { HardhatUserConfig } from "hardhat/config";
require("dotenv");

const accounts = [process.env.SOCKET_OWNER_PRIVATE_KEY, process.env.PLUG_OWNER_PRIVATE_KEY, process.env.PAUSER_PRIVATE_KEY];

function getRemappings() {
  return fs
    .readFileSync("remappings.txt", "utf8")
    .split("\n")
    .filter(Boolean)
    .map((line) => line.trim().split("="));
}

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.7",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      accounts: {},
      chainId: 31337,
    },
  },
  paths: {
    sources: "./src", // Use ./src rather than ./contracts as Hardhat expects
    cache: "./cache_hardhat", // Use a different cache for Hardhat than Foundry
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
  namedAccounts: {
    socketOwner: {
      default: 0,
    },
    counterOwner: {
      default: 1,
    },
    pauser: {
      default: 2,
    }
  }
};

export default config;
