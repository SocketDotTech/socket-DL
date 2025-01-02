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
import { executionManagerVersion } from "./config/config";

const main = async () => {
  try {
    const response = await prompts([
      {
        name: "chainType",
        type: "select",
        message: "Select chains network type",
        choices: [
          {
            title: "Mainnet",
            value: "mainnet",
          },
          {
            title: "Testnet",
            value: "testnet",
          },
        ],
      },
    ]);

    const chainOptions =
      response.chainType === "mainnet" ? MainnetIds : TestnetIds;
    let choices = chainOptions.map((chain) => ({
      title: chain.toString(),
      value: chain,
    }));

    const chainsResponse = await prompts([
      {
        name: "chains",
        type: "multiselect",
        message: "Select chains to connect",
        choices,
      },
      {
        name: "siblings",
        type: "multiselect",
        message: "Select sibling chains to connect",
        choices,
      },
    ]);

    const chains = chainsResponse.chains;
    const siblings = chainsResponse.siblings;
    const allChains = [...chains, ...siblings];
    console.log("allChains: ", allChains);

    choices = chains.map((chain) => ({
      title: chain.toString(),
      value: chain,
    }));

    const safeResponse = await prompts([
      {
        name: "chains",
        type: "multiselect",
        message: "Select chains to use Safe as owner",
        choices,
      },
    ]);

    let addresses: DeploymentAddresses = await deployForChains(
      allChains,
      safeResponse.chains,
      executionManagerVersion
    );

    if (chains.length === 0) {
      console.log("No siblings selected!");
      return;
    }

    await configureRoles(
      addresses,
      chains,
      siblings,
      safeResponse.chains,
      true,
      executionManagerVersion
    );
    addresses = await configureSwitchboards(
      addresses,
      chains,
      siblings,
      safeResponse.chains,
      executionManagerVersion
    );
    await connectPlugs(addresses, chains, siblings);
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
