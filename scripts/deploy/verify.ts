import hre from "hardhat";
import fs from "fs";

import { deploymentsPath, storeUnVerifiedParams, verify } from "./utils/utils";
import { mode } from "./config/config";
import { HardhatChainName, ChainSlugToKey, ChainSlug } from "../../src";

export type VerifyParams = {
  [chain in HardhatChainName]?: VerifyArgs[];
};
export type VerifyArgs = [string, string, string, any[]];

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
    if (!chains || chains.length === 0) {
      console.log("No chains found in verification params");
      return;
    }

    for (let chainIndex = 0; chainIndex < chains.length; chainIndex++) {
      const chain = parseInt(chains[chainIndex]) as ChainSlug;
      const networkName = ChainSlugToKey[chain];

      if (!networkName) {
        console.log(`⚠️  Unknown chain slug: ${chain}, skipping...`);
        continue;
      }

      console.log(
        `\n🔍 Verifying contracts on chain ${chain} (${networkName})`
      );

      try {
        hre.changeNetwork(networkName);
      } catch (error) {
        console.log(`❌ Failed to change network to ${networkName}:`, error);
        continue;
      }

      const chainParams: VerifyArgs[] = verificationParams[chain];
      if (!chainParams || chainParams.length === 0) {
        console.log(`⚠️  No contracts to verify for chain ${chain}`);
        continue;
      }

      const unverifiedChainParams: VerifyArgs[] = [];
      const len = chainParams.length;
      for (let index = 0; index < len; index++) {
        const res = await verify(...chainParams[index]);
        if (!res) {
          unverifiedChainParams.push(chainParams[index]);
        }
      }

      await storeUnVerifiedParams(unverifiedChainParams, chain, mode);
    }
  } catch (error) {
    console.log("Error in verifying contracts", error);
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
