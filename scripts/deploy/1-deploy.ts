import { chains } from "./config";
import { deployForChains } from "./scripts/deploySocketFor";

/**
 * Deploys network-independent socket contracts
 */
const deploy = async () => {
  try {
    await deployForChains(chains);
  } catch (error) {
    console.log("Error while deploying contracts");
  }
};

deploy()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
