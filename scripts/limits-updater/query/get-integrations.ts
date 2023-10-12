import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { ChainSocketAddresses, ChainSlug } from "../../../src";
import { getAddresses } from "../../deploy/utils";
import { mode } from "../../deploy/config";

// npx ts-node scripts/deploy/get-integrations.ts
export const getIntegrationsForAChainSlug = async (chainSlug: ChainSlug) => {
  const deployedAddressConfig: ChainSocketAddresses = (await getAddresses(
    chainSlug,
    mode
  )) as ChainSocketAddresses;

  console.log(
    `for chainSlugCode: ${chainSlug} , looked-up deployedAddressConfigs: ${JSON.stringify(
      deployedAddressConfig
    )}`
  );
};

// npx ts-node scripts/limits-updater/query/get-integrations.ts
export const getIntegrations = async () => {
  try {
    getIntegrationsForAChainSlug(ChainSlug.ARBITRUM_GOERLI);
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

getIntegrations()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
