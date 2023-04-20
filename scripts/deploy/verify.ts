import hre from "hardhat";
import { ChainKey, networkToChainSlug } from "../constants";
import verificationParams from "../../deployments/verification.json";
import { verify } from "./utils/utils";

export type VerifyParams = { [chain in ChainKey]?: any[][] };

/**
 * Deploys network-independent socket contracts
 */
export const main = async () => {
  try {
    const chains = Object.keys(verificationParams);
    for (let chainIndex = 0; chainIndex < chains.length; chainIndex++) {
      const chain = chains[chainIndex];
      hre.changeNetwork(networkToChainSlug[chain]);

      if (
        verificationParams &&
        verificationParams[chain] &&
        verificationParams[chain]?.length
      ) {
        const len = verificationParams[chain]?.length;
        for (let index = 0; index < len!; index++)
          await verify(...verificationParams[chain][index]);
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
