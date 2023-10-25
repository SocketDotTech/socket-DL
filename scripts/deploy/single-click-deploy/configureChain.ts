import { Wallet } from "ethers";
import fs from "fs";

import {
  CORE_CONTRACTS,
  ChainSlug,
  DeploymentAddresses,
  IntegrationTypes,
  ROLES,
} from "../../../src";
import { checkAndUpdateRoles } from "../scripts/roles";
import {
  chains,
  executionManagerVersion,
  executorAddresses,
  mode,
  newRoleStatus,
  sendTransaction,
  transmitterAddresses,
  watcherAddresses,
} from "../config";
import {
  configureExecutionManager,
  registerSwitchboards,
} from "../scripts/configureSocket";
import { getProviderFromChainSlug } from "../../constants";
import { deployedAddressPath, storeAllAddresses } from "../utils";
import { chainConfig } from "../../../chainConfig";

const chain = ChainSlug.SX_NETWORK_TESTNET;
const filterChains = [
  ChainSlug.POLYGON_MUMBAI,
  ChainSlug.GOERLI,
  ChainSlug.ARBITRUM_GOERLI,
];

export const main = async () => {
  const addresses: DeploymentAddresses = JSON.parse(
    fs.readFileSync(deployedAddressPath(mode), "utf-8")
  );

  // grant all roles for new chain
  await grantRoles();

  let addr;
  for (let c = 0; c < chains.length; c++) {
    const providerInstance = getProviderFromChainSlug(c as any as ChainSlug);
    const socketSigner: Wallet = new Wallet(
      process.env.SOCKET_SIGNER_KEY as string,
      providerInstance
    );

    // general configs for socket
    await configureExecutionManager(
      executionManagerVersion,
      addresses[c].ExecutionManager!,
      addresses[c].SocketBatcher,
      c,
      [chain],
      socketSigner
    );

    addr = await registerSwitchboards(
      c,
      [chain],
      CORE_CONTRACTS.FastSwitchboard2,
      IntegrationTypes.fast2,
      addresses[c],
      addresses,
      socketSigner
    );
  }
  await storeAllAddresses(addresses, mode);
};

const grantRoles = async () => {
  if (!chainConfig || !chainConfig[chain])
    throw new Error("Chain config not found!");
  const config = chainConfig[chain];

  if (
    !config.executorAddress ||
    !config.transmitterAddress ||
    !config.watcherAddress ||
    !config.feeUpdaterAddress ||
    !config.ownerAddress
  )
    throw new Error("Add all required addresses!");

  // Grant rescue,withdraw and governance role for Execution Manager to owner
  await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: transmitterAddresses[mode],
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
      {
        userAddress: executorAddresses[mode],
        filterRoles: [ROLES.EXECUTOR_ROLE],
      },
    ],
    contractName: executionManagerVersion,
    filterChains,
    filterSiblingChains: [chain],
    sendTransaction,
    newRoleStatus,
  });

  // Grant owner roles for TransmitManager
  await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: transmitterAddresses[mode],
        filterRoles: [ROLES.TRANSMITTER_ROLE],
      },
      {
        userAddress: transmitterAddresses[mode],
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
    ],
    contractName: CORE_CONTRACTS.TransmitManager,
    filterChains: chains,
    filterSiblingChains: [chain],
    sendTransaction,
    newRoleStatus,
  });

  // Setup Fast Switchboard2 roles
  await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: transmitterAddresses[mode],
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
      {
        userAddress: watcherAddresses[mode],
        filterRoles: [ROLES.WATCHER_ROLE],
      },
    ],

    contractName: CORE_CONTRACTS.FastSwitchboard2,
    filterChains: chains,
    filterSiblingChains: [chain],
    sendTransaction,
    newRoleStatus,
  });

  // Grant watcher role to watcher for OptimisticSwitchboard
  await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: transmitterAddresses[mode],
        filterRoles: [ROLES.FEES_UPDATER_ROLE], // all roles
      },
      {
        userAddress: watcherAddresses[mode],
        filterRoles: [ROLES.WATCHER_ROLE],
      },
    ],
    contractName: CORE_CONTRACTS.OptimisticSwitchboard,
    filterChains: chains,
    filterSiblingChains: [chain],
    sendTransaction,
    newRoleStatus,
  });
};

main();
