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
    const chainSlugs = Object.keys(ChainSlug);
    const chain = ChainSlug[chainSlugs[chainSlugs.length - 1]];

    const isMainnet = MainnetIds.includes(chain);
    const chainOptions = isMainnet ? MainnetIds : TestnetIds;
    let choices = chainOptions.map((chain) => ({
      title: chain.toString(),
      value: chain,
    }));
    choices = choices.filter(c => c.value !== chain)
    const configResponse = await prompts([
      {
        name: "chains",
        type: "multiselect",
        message: "Select sibling chains to connect",
        choices,
      },
    ]);

    const chains = configResponse.chains;

    let addresses: DeploymentAddresses = await deployForChains(chains);

    if (chains.length === 0) {
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
