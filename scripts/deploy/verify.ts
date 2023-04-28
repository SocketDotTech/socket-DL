import hre from "hardhat";
import fs from "fs";

import { deploymentsPath, verify } from "./utils/utils";
import { mode } from "./config";
import { ChainKey, networkToChainSlug } from "../../src";

export type VerifyParams = {
  [chain in ChainKey]?: VerifyArgs[];
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
    if (!chains) return;

    for (let chainIndex = 0; chainIndex < chains.length; chainIndex++) {
      const chain = chains[chainIndex];

      hre.changeNetwork(networkToChainSlug[chain]);
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
