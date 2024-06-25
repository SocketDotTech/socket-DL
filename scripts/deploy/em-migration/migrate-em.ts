require("dotenv").config();
import {
  CORE_CONTRACTS,
  ChainSlug,
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

const deploy = async (chains: ChainSlug[]) => {
  try {
    const addresses: DeploymentAddresses = await deployForChains(
      chains,
      emVersion
    );
    await configureRoles(addresses, chains, true, emVersion);
  } catch (error) {
    console.log("Error:", error);
  }
};

const configure = async (chains: ChainSlug[]) => {
  try {
    const addresses: DeploymentAddresses = await deployForChains(
      chains,
      emVersion
    );
    await configureSwitchboards(addresses, chains, emVersion);
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

  switch (response.action) {
    case "configure":
      await configure(chains);
      break;
    case "deploy":
      await deploy(chains);
      break;
    case "exit":
      process.exit(0);
  }
};

// npx hardhat run scripts/deploy/em-migration/migrate-em.ts
main();

// run this script, select deploy and upload s3 config
// run the fees updater for new EM
// check if fees set on all EMs for all paths with ./check-migration script
// run the script again for configuration
// run the ./check-migration script to test if all chains have latest EM
