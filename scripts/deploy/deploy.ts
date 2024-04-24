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

const main = async () => {
  try {
    const response = await prompts([
      {
        name: "isMainnet",
        type: "toggle",
        message: "Is it a mainnet?",
      },
    ]);

    const chainOptions = response.isMainnet ? MainnetIds : TestnetIds;
    const choices = chainOptions.map((chain) => ({
      title: chain.toString(),
      value: chain,
    }));

    const configResponse = await prompts([
      {
        name: "chains",
        type: "multiselect",
        message: "Select chains to connect",
        choices,
      },
    ]);

    const chains = configResponse.chains;

    if (chains.length === 0) {
      console.log("No chains selected!");
      return;
    }

    let addresses: DeploymentAddresses = await deployForChains(chains);

    if (chains.length === 1) {
      console.log("No siblings selected!");
      return;
    }
    await configureRoles(addresses, chains, true);
    addresses = await configureSwitchboards(addresses, chains);
    await connectPlugs(addresses, chains);
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
