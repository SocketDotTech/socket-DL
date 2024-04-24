import hre from "hardhat";
import fs from "fs";
import readlineSync from "readline-sync";

import { deploymentsPath, verify } from "./utils/utils";
import { mode } from "./config";
import {
  HardhatChainName,
  ChainSlugToKey,
  ChainSlug,
  ChainSlugToId,
  hardhatChainNameToSlug,
} from "../../src";

export type VerifyParams = {
  [chain in HardhatChainName]?: VerifyArgs[];
};
type VerifyArgs = [string, string, string, any[]];

const getNetworkIdFromArg = (): number => {
  const args = process.argv;
  let networkName = "";
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--network" && i + 1 < args.length) {
      networkName = args[i + 1];
      break;
    }
  }
  return parseInt(networkName);
};

/**
 * Deploys network-independent socket contracts
 */
export const main = async () => {
  try {
    let chains = [];

    const path = deploymentsPath + `${mode}_verification.json`;
    if (!fs.existsSync(path)) {
      throw new Error("addresses.json not found");
    }
    const verificationParams: VerifyParams = JSON.parse(
      fs.readFileSync(path, "utf-8")
    );

    // if network is passed as param we only run the script for that network
    chains = getNetworkIdFromArg()
      ? [getNetworkIdFromArg()]
      : [Object.keys(verificationParams)];
    if (!chains) return;

    for (let chainIndex = 0; chainIndex < chains.length; chainIndex++) {
      const chain = parseInt(chains[chainIndex]) as ChainSlug;
      hre.changeNetwork(ChainSlugToKey[chain]);
      const chainParams: VerifyArgs[] = verificationParams[chain];
      if (chainParams.length) {
        const len = chainParams.length;
        for (let index = 0; index < len!; index++)
          await verify(...chainParams[index]);
      }
    }
  } catch (error) {
    console.log("Error in deploying setup contracts", error);
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
