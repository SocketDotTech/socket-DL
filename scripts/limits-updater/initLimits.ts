import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import {
  ChainAddresses,
  ChainSocketAddresses,
  Integrations,
  ChainSlug,
} from "../../src";
import { getAddresses } from "../deploy/utils";
import { mode } from "../deploy/config/config";

export const setLimitsForAChainSlug = async (chainSlugCode: ChainSlug) => {
  try {
    console.log(`setting initLimits for chainSlug: ${chainSlugCode}`);

    const deployedAddressConfig = (await getAddresses(
      chainSlugCode,
      mode
    )) as ChainSocketAddresses;

    console.log(
      `deployedAddressConfig are: ${JSON.stringify(deployedAddressConfig)}`
    );

    const integrations: Integrations =
      deployedAddressConfig.integrations as Integrations;

    console.log(`integrations are: ${JSON.stringify(integrations)}`);

    //get TransmitManager Address
    const transmitManagerAddress =
      deployedAddressConfig.TransmitManager as string;

    if (integrations) {
      console.log(`For sourceChainId: ${chainSlugCode} \n`);

      const keys = Object.keys(integrations);
      const values = Object.values(integrations);

      for (let i = 0; i < keys.length; i++) {
        const key = keys[i].toString();
        const dstChainId = parseInt(key);
        const chainAddresses: ChainAddresses = values[i];

        const chainSlugCode = "optimism-goerli";
      }

      console.log(`-------------------------------------\n\n`);
    }
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

// npx ts-node scripts/limits-updater/initLimits.ts
export const setLimits = async () => {
  try {
    setLimitsForAChainSlug(ChainSlug.OPTIMISM_GOERLI);
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

setLimits()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
