import {
  CORE_CONTRACTS,
  DeploymentAddresses,
  MainnetIds,
  ROLES,
  TestnetIds,
} from "../../../src";
import { deployForChains } from "../scripts/deploySocketFor";
import prompts from "prompts";
import { checkAndUpdateRoles } from "../scripts/roles";
import {
  executorAddresses,
  mode,
  ownerAddresses,
  transmitterAddresses,
} from "../config/config";
import { configureExecutionManagers } from "./migrate-em";

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

    await checkAndUpdateRoles(
      {
        userSpecificRoles: [
          {
            userAddress: ownerAddresses[mode],
            filterRoles: [
              ROLES.RESCUE_ROLE,
              ROLES.GOVERNANCE_ROLE,
              ROLES.WITHDRAW_ROLE,
              ROLES.FEES_UPDATER_ROLE,
            ],
          },
          {
            userAddress: transmitterAddresses[mode],
            filterRoles: [ROLES.FEES_UPDATER_ROLE],
          },
          {
            userAddress: executorAddresses[mode],
            filterRoles: [ROLES.EXECUTOR_ROLE],
          },
        ],
        contractName: emVersion,
        filterChains: chains,
        filterSiblingChains: chains,
        sendTransaction: true,
        newRoleStatus: true,
      },
      addresses
    );
    await configureExecutionManagers(chains, addresses);
  } catch (error) {
    console.log("Error:", error);
  }
};

//  npx hardhat run scripts/deploy/em-migration/backward-migrate-em.ts
deploy();

// run this script, update s3 config version and upload s3 config
// run em fees updater
// run the ./check-migration script to test if new EM is set and it has initial fees
