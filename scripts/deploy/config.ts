import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { DeploymentMode, MainnetIds } from "../../src";
import { ChainKey } from "../constants";

export const mode = process.env.DEPLOYMENT_MODE as
  | DeploymentMode
  | DeploymentMode.DEV;

console.log("========================================================");
console.log("Deployment started for MODE", mode);
console.log("========================================================");

export const chains: Array<ChainKey> = [
  ChainKey.GOERLI,
  ChainKey.ARBITRUM_GOERLI,
  ChainKey.OPTIMISM_GOERLI,
  ChainKey.POLYGON_MUMBAI,
  ChainKey.BSC_TESTNET,
  ChainKey.MAINNET,
  ChainKey.ARBITRUM,
  ChainKey.OPTIMISM,
  ChainKey.BSC,
  ChainKey.POLYGON_MAINNET,
];

export const sendTransaction = false;
export const newRoleStatus = false;
export const filterChains: number[] = [...MainnetIds];

export const capacitorType = 1;
export const maxPacketLength = 1;

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
