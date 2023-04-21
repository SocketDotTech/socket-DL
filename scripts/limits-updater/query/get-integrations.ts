import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { DeploymentMode, chainSlugs } from "../../constants";
import { ChainSocketAddresses } from "../../../src/types";
import { getAddresses } from "../../deploy/utils";

const mode = process.env.DEPLOYMENT_MODE as DeploymentMode | DeploymentMode.DEV;

// npx ts-node scripts/deploy/get-integrations.ts
export const getIntegrationsForAChainSlug = async (
  chainSlug: keyof typeof chainSlugs
) => {
  const chainId = chainSlugs[chainSlug];

  const deployedAddressConfig: ChainSocketAddresses = (await getAddresses(
    chainId,
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
    getIntegrationsForAChainSlug("arbitrum-goerli");
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
