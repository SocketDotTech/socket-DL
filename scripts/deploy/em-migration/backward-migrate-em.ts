import {
  CORE_CONTRACTS,
  DeploymentAddresses,
  MainnetIds,
  TestnetIds,
} from "../../../src";
import { configureRoles } from "../scripts/configureRoles";
import { configureSwitchboards } from "../scripts/configureSwitchboards";
import { deployForChains } from "../scripts/deploySocketFor";
import prompts from "prompts";

const deploy = async () => {
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

    const emVersion = CORE_CONTRACTS.ExecutionManager;
    const addresses: DeploymentAddresses = await deployForChains(
      chains,
      emVersion
    );

    await configureRoles(addresses, chains, true, emVersion);
    await configureSwitchboards(addresses, chains, emVersion);
  } catch (error) {
    console.log("Error:", error);
  }
};

deploy();

// run this script and upload s3 config
// run the ./check-migration script to test if new EM is set
