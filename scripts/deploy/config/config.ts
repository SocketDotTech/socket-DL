import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import {
  ChainSlug,
  DeploymentMode,
  CORE_CONTRACTS,
  version,
} from "../../../src";
import { BigNumberish, utils } from "ethers";
import chainConfig from "../../../chainConfig.json";
import { getOverrides } from "../../constants/overrides";
import { getProviderFromChainSlug } from "../../constants";

export const mode = process.env.DEPLOYMENT_MODE as
  | DeploymentMode
  | DeploymentMode.DEV;

// if (!process.env.SOCKET_OWNER_ADDRESS)
//   throw Error("Socket owner address not present");
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
  // ChainSlug.GOERLI,
  // ChainSlug.ARBITRUM_SEPOLIA,
  // ChainSlug.OPTIMISM_SEPOLIA,
  // ChainSlug.SX_NETWORK_TESTNET,
  // ChainSlug.SX_NETWORK,
  // ChainSlug.MODE_TESTNET,
  // ChainSlug.VICTION_TESTNET,
  // ChainSlug.AEVO_TESTNET,
  // ChainSlug.LYRA_TESTNET,
  // ChainSlug.SEPOLIA,
  // ChainSlug.XAI_TESTNET,
  // ChainSlug.AEVO,
  ChainSlug.MAINNET,
  ChainSlug.ARBITRUM,
  ChainSlug.OPTIMISM,
  ChainSlug.POLYGON_MAINNET,
  ChainSlug.LYRA,
  // ChainSlug.BSC,
  ChainSlug.BASE,
  ChainSlug.MODE,
  // ChainSlug.ANCIENT8_TESTNET,
  // ChainSlug.ANCIENT8_TESTNET2,
  // ChainSlug.SYNDR_SEPOLIA_L3,
  // ChainSlug.PARALLEL,
  // ChainSlug.MANTLE,
  // ChainSlug.REYA_CRONOS,
  // ChainSlug.REYA,
  // ChainSlug.POLYNOMIAL_TESTNET,
  // ChainSlug.BOB,
  // ChainSlug.SIPHER_FUNKI_TESTNET,
  // ChainSlug.WINR,
  ChainSlug.BLAST,
];

export const executionManagerVersion = CORE_CONTRACTS.ExecutionManagerDF;
export const sendTransaction = true;
export const newRoleStatus = true;
export const filterChains: number[] = chains;
export const filterSiblingChains: number[] = chains;
export const capacitorType = 1;
export const maxPacketLength = 1;
export const initialPacketCount = 0;

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
  // [DeploymentMode.PROD]: "0xA3a585c6d59CCE6aAe7035e8df48b3327cC8BE54", // sx testnet watcher 1
  // [DeploymentMode.PROD]: "0x7EFF16a34e3433182D636488bc97919b10283F37", // sx testnet watcher 2
  // [DeploymentMode.PROD]: "0x8fB53330b1AEa01f6d34faff90e0B7c2797FC3aD", // sx watcher 1
  // [DeploymentMode.PROD]: "0xE8D6b3eE50887c131D64065a97CCC786dF0bA336", // sx watcher 2
  // [DeploymentMode.PROD]: "0x3b9FF70BcdF0B459A92fce1AbE5A6A713261BA75", // sx watcher 3
  // [DeploymentMode.PROD]: "0x5Ca565e0952C44DBF1986988ba4d10A171D45FB9", // sx watcher 4
};

export const executorAddresses = {
  // [DeploymentMode.DEV]: "0x8e90345042b2720F33138CC437f8f897AC84A095", // private key
  [DeploymentMode.DEV]: "0x5ea69806b1df5dbdc6c1a78c662682ca48f9524d", // kms
  [DeploymentMode.SURGE]: "0x3051Aa7F267bF425A4e8bF766750D60391F014B4",
  [DeploymentMode.PROD]: "0x42639d8fd154b72472e149a7d5ac13fa280303d9",
};

export const ownerAddresses = {
  [DeploymentMode.DEV]: socketOwner,
  [DeploymentMode.SURGE]: socketOwner,
  [DeploymentMode.PROD]: socketOwner,
};

export const hexagateTripRoleOwners = {
  [DeploymentMode.DEV]: "0x081871d78fe7c35c774ce3b4d4ba6592519db223",
  [DeploymentMode.SURGE]: "0x081871d78fe7c35c774ce3b4d4ba6592519db223",
  [DeploymentMode.PROD]: "0xb810a120dd88746c039894bc6397508bdb762e86",
};

export const overrides = async (
  chain: ChainSlug | number
): Promise<{
  type?: number | undefined;
  gasLimit?: BigNumberish | undefined;
  gasPrice?: BigNumberish | undefined;
}> => {
  if (chainConfig[chain]?.overrides) {
    return chainConfig[chain].overrides;
  }
  return await getOverrides(chain, getProviderFromChainSlug(chain));
};
