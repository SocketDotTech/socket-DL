require("dotenv").config();
import {
  CORE_CONTRACTS,
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  MainnetIds,
  ROLES,
  TestnetIds,
  getAllAddresses,
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
import {
  configureExecutionManager,
  setManagers,
} from "../scripts/configureSocket";
import { Wallet } from "ethers";
import { getProviderFromChainSlug } from "../../constants";
import { storeAllAddresses } from "../utils";
import { getSiblingsFromAddresses } from "../../common";

const emVersion = CORE_CONTRACTS.ExecutionManagerDF;

export const configureExecutionManagers = async (
  chains: ChainSlug[],
  addresses
) => {
  try {
    await Promise.all(
      chains.map(async (chain) => {
        const providerInstance = getProviderFromChainSlug(
          chain as any as ChainSlug
        );
        const socketSigner: Wallet = new Wallet(
          process.env.SOCKET_SIGNER_KEY as string,
          providerInstance
        );

        let addr: ChainSocketAddresses = addresses[chain]!;

        const siblingSlugs: ChainSlug[] = getSiblingsFromAddresses(addr);

        await configureExecutionManager(
          emVersion,
          addr[emVersion]!,
          addr[CORE_CONTRACTS.SocketBatcher],
          chain,
          siblingSlugs,
          socketSigner
        );

        await setManagers(addr, socketSigner, emVersion);
      })
    );
  } catch (error) {
    console.log(error);
    throw error;
  }
};

const deleteOldContracts = async (chains: ChainSlug[]) => {
  try {
    const addresses: DeploymentAddresses = getAllAddresses(mode);
    await Promise.all(
      Object.keys(addresses).map(async (chain) => {
        if (chains.includes(parseInt(chain) as ChainSlug)) {
          addresses[chain].Counter = "";
          addresses[chain].SocketBatcher = "";
        }
      })
    );

    await storeAllAddresses(addresses, mode);
  } catch (error) {
    console.log("Error:", error);
  }
};

const deploy = async (chains: ChainSlug[]) => {
  try {
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

    await configureExecutionManagers(chains, addresses);
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
        {
          title: "Delete",
          value: "delete",
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
    case "delete":
      await deleteOldContracts(chains);
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
