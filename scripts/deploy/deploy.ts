import {
  ChainSlug,
  DeploymentAddresses,
  MainnetIds,
  TestnetIds,
} from "../../src";
import { configureRoles } from "./scripts/configureRoles";
import { deployForChains } from "./scripts/deploySocketFor";
import { configureSwitchboards } from "./scripts/configureSwitchboards";
import { connectPlugs } from "./scripts/connect";
import prompts from "prompts";
import { chains, executionManagerVersion } from "./config/config";

const main = async () => {
  try {
    const chains = process.env.BUNGEE_CHAINS.split(",").map(
      (c) => parseInt(c) as ChainSlug
    );

    const siblings = process.env.BUNGEE_SIBLINGS.split(",").map(
      (c) => parseInt(c) as ChainSlug
    );
    const safeChains = process.env.SAFE_CHAINS.split(",").map(
      (c) => parseInt(c) as ChainSlug
    );
    const allChains = [...chains, ...siblings];

    let addresses: DeploymentAddresses = await deployForChains(
      allChains,
      safeChains,
      executionManagerVersion
    );

    if (chains.length === 0) {
      console.log("No siblings selected!");
      return;
    }

    for (const chain of chains) {
      await configureRoles(
        addresses,
        [chain],
        siblings,
        safeChains,
        true,
        executionManagerVersion
      );
    }
    for (const sibling of siblings) {
      addresses = await configureSwitchboards(
        addresses,
        chains,
        [sibling],
        safeChains,
        executionManagerVersion
      );
    }
    await connectPlugs(addresses, chains, siblings, []);
  } catch (error) {
    console.log("Error:", error);
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
