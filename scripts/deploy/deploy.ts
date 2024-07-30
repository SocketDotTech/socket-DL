import { DeploymentAddresses, MainnetIds, TestnetIds } from "../../src";
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

    const configResponse = await prompts([
      {
        name: "chains",
        type: "multiselect",
        message: "Select sibling chains to connect",
        choices,
      },
    ]);

    const chains = [...configResponse.chains];
    let addresses: DeploymentAddresses = await deployForChains(
      chains,
      executionManagerVersion
    );

    if (chains.length === 0) {
      console.log("No siblings selected!");
      return;
    }

    await configureRoles(addresses, chains, true, executionManagerVersion);
    addresses = await configureSwitchboards(
      addresses,
      chains,
      executionManagerVersion
    );
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
