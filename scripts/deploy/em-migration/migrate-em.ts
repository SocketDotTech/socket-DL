require("dotenv").config();
import {
  CORE_CONTRACTS,
  DeploymentAddresses,
  DeploymentMode,
  MainnetIds,
  TestnetIds,
  getAllAddresses,
} from "../../../src";
import { configureRoles } from "../scripts/configureRoles";
import { configureSwitchboards } from "../scripts/configureSwitchboards";
import { deployForChains } from "../scripts/deploySocketFor";
import prompts from "prompts";

const deploymentMode = process.env.DEPLOYMENT_MODE as DeploymentMode;
const emVersion = CORE_CONTRACTS.ExecutionManagerDF;

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
    const addresses: DeploymentAddresses = await deployForChains(
      chains,
      CORE_CONTRACTS.ExecutionManagerDF
    );
    await configureRoles(addresses, chains, true, emVersion);
  } catch (error) {
    console.log("Error:", error);
  }
};

const configure = async () => {
  try {
    let addresses: DeploymentAddresses = getAllAddresses(deploymentMode);
    const chains = [...MainnetIds, ...TestnetIds];

    addresses = await configureSwitchboards(addresses, chains, emVersion);
  } catch (error) {
    console.log("Error:", error);
  }
};

const main = async () => {
  const response = await prompts([
    {
      name: "action",
      type: "select",
      message: "Select execution manager action",
      choices: [
        {
          title: "Deploy and set roles",
          value: "deploy",
        },
        {
          title: "Configure",
          value: "configure",
        },
      ],
    },
  ]);

  switch (response.option) {
    case "configure":
      await configure();
      break;
    case "deploy":
      await deploy();
      break;
    case "exit":
      process.exit(0);
  }
};

main();

// run this script, select deploy and upload s3 config
// run the fees updater for new EM
// check if fees set on all EMs for all paths
// run the script again for configuration
// run the ./check-migration script to test if all chains have latest EM
