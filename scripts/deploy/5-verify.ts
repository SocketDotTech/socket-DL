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

/**
 * Deploys network-independent socket contracts
 */
export const main = async () => {
  try {
    const path = deploymentsPath + `${mode}_verification.json`;
    if (!fs.existsSync(path)) {
      throw new Error("addresses.json not found");
    }
    let verificationParams: VerifyParams = JSON.parse(
      fs.readFileSync(path, "utf-8")
    );

    const chains = Object.keys(verificationParams);
    const configChains = Object.keys(hre.config.networks).filter(
      (item) => !["localhost", "hardhat"].includes(item)
    );

    if (chains.length !== configChains.length) {
      console.log(
        "Networks in hardhat.config.ts and verification.json do not match."
      );
      console.log(
        `Verification will proceed only for chains in hardhat.config.ts: [${configChains}]. Do you want to proceed?`
      );
      const answer = readlineSync.question("Enter y/n: ");
      if (answer !== "y") return;
    }

    if (!configChains) return;

    for (let chainIndex = 0; chainIndex < configChains.length; chainIndex++) {
      const chainName = configChains[chainIndex];
      const chainId = hardhatChainNameToSlug[chainName];

      console.log(`Verifying contracts for ${chainName}`);
      hre.changeNetwork(chainName);
      const chainParams: VerifyArgs[] = verificationParams[chainId];
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
