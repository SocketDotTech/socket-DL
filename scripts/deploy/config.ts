import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import {
  ChainKey,
  ChainSlug,
  DeploymentMode,
  TestnetIds,
  CORE_CONTRACTS,
} from "../../src";
import { BigNumberish, utils } from "ethers";
export const mode = process.env.DEPLOYMENT_MODE as
  | DeploymentMode
  | DeploymentMode.DEV;

if (!process.env.SOCKET_OWNER_ADDRESS)
  throw Error("Socket owner address not present");
export const socketOwner = process.env.SOCKET_OWNER_ADDRESS;

console.log("========================================================");
console.log("Deployment started for MODE", mode);
console.log(
  `Make sure ${mode}_addresses.json and ${mode}_verification.json is cleared for given networks if redeploying!!`
);
console.log(`Owner address configured to ${socketOwner}`);
console.log("========================================================");

export const chains: Array<ChainSlug> = [
  // ChainSlug.GOERLI,
  ChainSlug.ARBITRUM_GOERLI,
  ChainSlug.OPTIMISM_GOERLI,
  // ChainSlug.POLYGON_MUMBAI,
  // ChainSlug.BSC_TESTNET,
  // ChainSlug.MAINNET,
  // ChainSlug.ARBITRUM,
  // ChainSlug.OPTIMISM,
  // ChainSlug.BSC,
  // ChainSlug.POLYGON_MAINNET,
];

export const executionManagerVersion = CORE_CONTRACTS.OpenExecutionManager;
export const sendTransaction = true;
export const newRoleStatus = true;
export const filterChains: number[] = chains;

export const capacitorType = 1;
export const maxPacketLength = 1;
export const initialPacketCount = 0;

export const gasLimit = undefined;
export const gasPrice = undefined;
export const type = 0;

export const msgValueMaxThreshold: { [chain in ChainSlug]?: BigNumberish } = {
  [ChainSlug.ARBITRUM_GOERLI]: utils.parseEther("0.001"),
  [ChainSlug.OPTIMISM_GOERLI]: utils.parseEther("0.001"),
  [ChainSlug.POLYGON_MUMBAI]: utils.parseEther("0.1"),
  [ChainSlug.BSC_TESTNET]: utils.parseEther("0.001"),
  [ChainSlug.GOERLI]: utils.parseEther("0.001"),
  [ChainSlug.ARBITRUM]: utils.parseEther("0.001"),
  [ChainSlug.OPTIMISM]: utils.parseEther("0.001"),
  [ChainSlug.POLYGON_MAINNET]: utils.parseEther("0.1"),
  [ChainSlug.BSC]: utils.parseEther("0.001"),
  [ChainSlug.MAINNET]: utils.parseEther("0.001"),
};

export const transmitterAddresses = {
  [DeploymentMode.DEV]: "0x138e9840861C983DC0BB9b3e941FB7C0e9Ade320",
  [DeploymentMode.SURGE]: "0x22883bEF8302d50Ac76c6F6e048965Cd4413EBb7",
  [DeploymentMode.PROD]: "0xB7C86F3ad1523fF7d13979dc72620789e95F67B9",
};

export const watcherAddresses = {
  [DeploymentMode.DEV]: "0xBe6fC90D42bED21d722D5698aF2916C3a3b1393D",
  [DeploymentMode.SURGE]: "0xD7Ab0e4c8c31A91fb26552F7Ad3E91E169B86225",
  [DeploymentMode.PROD]: "0x806b72358b37391cA4220d705d225d85dc74EBc1",
};

export const executorAddresses = {
  [DeploymentMode.DEV]: "0x8e90345042b2720F33138CC437f8f897AC84A095",
  [DeploymentMode.SURGE]: "0x3051Aa7F267bF425A4e8bF766750D60391F014B4",
  [DeploymentMode.PROD]: "0x557E729E55d49E767c11982d026a63aBFD930Ac9",
};

export const overrides: {
  [chain in ChainSlug | number]?: {
    type?: number | undefined;
    gasLimit?: BigNumberish | undefined;
    gasPrice?: BigNumberish | undefined;
  };
} = {
  [ChainSlug.ARBITRUM]: {
    type,
    gasLimit: 20_000_000,
    gasPrice,
  },
  [ChainSlug.ARBITRUM_GOERLI]: {
    // type,
    // gasLimit: 20_000_000,
    // gasPrice,
  },
  [ChainSlug.OPTIMISM]: {
    type,
    gasLimit: 2_000_000,
    gasPrice,
  },
  [ChainSlug.OPTIMISM_GOERLI]: {
    // type,
    // gasLimit: 20_000_000,
    // gasPrice,
  },
  [ChainSlug.BSC]: {
    type,
    gasLimit,
    gasPrice,
  },
  [ChainSlug.BSC_TESTNET]: {
    type,
    gasLimit,
    gasPrice,
  },
  [ChainSlug.MAINNET]: {
    type,
    gasLimit,
    gasPrice,
  },
  [ChainSlug.GOERLI]: {
    type,
    gasLimit: 3_000_000,
    gasPrice,
  },
  [ChainSlug.POLYGON_MAINNET]: {
    type,
    gasLimit,
    gasPrice: 250_000_000_000,
  },
  [ChainSlug.POLYGON_MUMBAI]: {
    type: 0,
    gasLimit: 2_000_000,
    gasPrice,
  },
};
