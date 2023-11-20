import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { ChainSlug, DeploymentMode, CORE_CONTRACTS, version } from "../../src";
import { BigNumberish, utils } from "ethers";
import chainConfig from "../../chainConfig.json";

export const mode = process.env.DEPLOYMENT_MODE as
  | DeploymentMode
  | DeploymentMode.DEV;

if (!process.env.SOCKET_OWNER_ADDRESS)
  throw Error("Socket owner address not present");
export const socketOwner = process.env.SOCKET_OWNER_ADDRESS;

console.log(
  "================================================================================================================"
);
console.log("");
console.log(`Mode: ${mode}`);
console.log(`Version: ${version[mode]}`);
console.log(`Owner: ${socketOwner}`);
console.log("");
console.log(
  `Make sure ${mode}_addresses.json and ${mode}_verification.json is cleared for given networks if redeploying!!`
);
console.log("");
console.log(
  "================================================================================================================"
);

export const chains: Array<ChainSlug> = [
  ChainSlug.GOERLI,
  ChainSlug.ARBITRUM_SEPOLIA,
  ChainSlug.OPTIMISM_SEPOLIA,
  ChainSlug.POLYGON_MUMBAI,
  ChainSlug.SX_NETWORK_TESTNET,
  ChainSlug.BSC_TESTNET,
  ChainSlug.AEVO_TESTNET,
  ChainSlug.LYRA_TESTNET,
  ChainSlug.SEPOLIA,
  ChainSlug.XAI_TESTNET,
  ChainSlug.CDK_TESTNET,
  ChainSlug.AEVO,
  ChainSlug.MAINNET,
  ChainSlug.ARBITRUM,
  ChainSlug.OPTIMISM,
  ChainSlug.LYRA,
  ChainSlug.BSC,
  ChainSlug.POLYGON_MAINNET,
];

export const executionManagerVersion = CORE_CONTRACTS.ExecutionManager;
export const sendTransaction = true;
export const newRoleStatus = true;
export const filterChains: number[] = chains;
export const filterSiblingChains: number[] = chains;
export const capacitorType = 1;
export const maxPacketLength = 1;
export const initialPacketCount = 0;

export const gasLimit = undefined;
export const gasPrice = undefined;
export const type = 0;

const MSG_VALUE_MAX_THRESHOLD = utils.parseEther("0.001");
export const msgValueMaxThreshold = (chain: ChainSlug): BigNumberish => {
  if (chainConfig[chain] && chainConfig[chain].msgValueMaxThreshold)
    return chainConfig[chain].msgValueMaxThreshold!;
  return MSG_VALUE_MAX_THRESHOLD;
};

export const transmitterAddresses = {
  [DeploymentMode.DEV]: "0x138e9840861C983DC0BB9b3e941FB7C0e9Ade320",
  [DeploymentMode.SURGE]: "0x22883bEF8302d50Ac76c6F6e048965Cd4413EBb7",
  [DeploymentMode.PROD]: "0xfbc5ea2525bb827979e4c33b237cd47bcb8f81c5",
};

export const watcherAddresses = {
  [DeploymentMode.DEV]: "0xBe6fC90D42bED21d722D5698aF2916C3a3b1393D",
  [DeploymentMode.SURGE]: "0xD7Ab0e4c8c31A91fb26552F7Ad3E91E169B86225",
  [DeploymentMode.PROD]: "0x75ddddf61b8180d3837b7d8b98c062ca442e0e14", // prod
  // [DeploymentMode.PROD]: "0x55296741c6d72a07f3965abab04737c29016f2eb", // aevo watcher
};

export const executorAddresses = {
  [DeploymentMode.DEV]: "0x8e90345042b2720F33138CC437f8f897AC84A095",
  [DeploymentMode.SURGE]: "0x3051Aa7F267bF425A4e8bF766750D60391F014B4",
  [DeploymentMode.PROD]: "0x42639d8fd154b72472e149a7d5ac13fa280303d9",
};

export const overrides = (
  chain: ChainSlug | number
): {
  type?: number | undefined;
  gasLimit?: BigNumberish | undefined;
  gasPrice?: BigNumberish | undefined;
} => {
  if (chain == ChainSlug.ARBITRUM) {
    return {
      type,
      gasLimit: 20_000_000,
      gasPrice,
    };
  } else if (chain == ChainSlug.ARBITRUM_GOERLI) {
    return {
      // type,
      // gasLimit: 20_000_000,
      // gasPrice,
    };
  } else if (chain == ChainSlug.OPTIMISM) {
    return {
      type,
      gasLimit: 2_000_000,
      gasPrice,
    };
  } else if (chain == ChainSlug.OPTIMISM_GOERLI) {
    return {
      // type,
      // gasLimit: 20_000_000,
      // gasPrice,
    };
  } else if (chain == ChainSlug.BSC) {
    return {
      type,
      gasLimit,
      gasPrice,
    };
  } else if (chain == ChainSlug.BSC_TESTNET) {
    return {
      type,
      gasLimit,
      gasPrice,
    };
  } else if (chain == ChainSlug.MAINNET) {
    return {
      type,
      gasLimit,
      gasPrice,
    };
  } else if (chain == ChainSlug.GOERLI) {
    return {
      type,
      gasLimit: 3_000_000,
      gasPrice,
    };
  } else if (chain == ChainSlug.POLYGON_MAINNET) {
    return {
      type,
      gasLimit,
      gasPrice: 250_000_000_000,
    };
  } else if (chain == ChainSlug.POLYGON_MUMBAI) {
    return {
      type: 0,
      gasLimit: 2_000_000,
      gasPrice,
    };
  } else if (chain == ChainSlug.SEPOLIA) {
    return {
      type,
      gasLimit,
      gasPrice,
    };
  } else if (chain == ChainSlug.AEVO_TESTNET) {
    return {
      type: 2,
      // gasLimit,
      // gasPrice,
    };
  } else if (chain == ChainSlug.AEVO) {
    return {
      type: 1,
      // gasLimit,
      gasPrice: 100_000_000,
    };
  } else if (chain == ChainSlug.LYRA_TESTNET) {
    return {
      type: 2,
      // gasLimit,
      // gasPrice: 100_000_000,
    };
  } else if (chain == ChainSlug.LYRA) {
    return {
      // type: 1,
      // gasLimit,
      // gasPrice: 100_000_000,
    };
  } else if (chain == ChainSlug.XAI_TESTNET) {
    return {
      // type: 1,
      // gasLimit,
      // gasPrice: 100_000_000,
    };
  } else if (chain == ChainSlug.SX_NETWORK_TESTNET) {
    return {
      // type: 1,
      // gasLimit,
      // gasPrice: 100_000_000,
    };
  } else if (chainConfig[chain] && chainConfig[chain].overrides) {
    return chainConfig[chain].overrides!;
  } else return { type, gasLimit, gasPrice };
};
