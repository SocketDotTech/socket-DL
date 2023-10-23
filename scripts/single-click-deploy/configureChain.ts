import { Wallet } from "ethers";
import fs from "fs";

import {
  CORE_CONTRACTS,
  ChainSlug,
  DeploymentAddresses,
  IntegrationTypes,
  ROLES,
} from "../../src";
import { checkAndUpdateRoles } from "../deploy/checkRoles";
import {
  chains,
  executionManagerVersion,
  executorAddresses,
  filterSiblingChains,
  mode,
  newRoleStatus,
  sendTransaction,
  socketOwner,
  transmitterAddresses,
  watcherAddresses,
} from "../deploy/config";
import {
  configureExecutionManager,
  registerSwitchboards,
} from "../deploy/configure";
import { getProviderFromChainSlug } from "../constants";
import { deployedAddressPath, storeAllAddresses } from "../deploy/utils";

export const main = async () => {
  const addresses: DeploymentAddresses = JSON.parse(
    fs.readFileSync(deployedAddressPath(mode), "utf-8")
  );

  let addr;
  for (let c = 0; c < chains.length; c++) {
    const providerInstance = getProviderFromChainSlug(c as any as ChainSlug);
    const socketSigner: Wallet = new Wallet(
      process.env.SOCKET_SIGNER_KEY as string,
      providerInstance
    );

    // grant all roles for new chain
    await grantRoles();

    // general configs for socket
    await configureExecutionManager(
      executionManagerVersion,
      addresses[c].ExecutionManager!,
      addresses[c].SocketBatcher,
      c,
      filterSiblingChains,
      socketSigner
    );

    addr = await registerSwitchboards(
      c,
      filterSiblingChains,
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
  // Grant rescue,withdraw and governance role for Execution Manager to owner
  await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: socketOwner,
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
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
    contractName: executionManagerVersion,
    filterChains: chains,
    filterSiblingChains,
    sendTransaction,
    newRoleStatus,
  });

  // Grant owner roles for TransmitManager
  await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: socketOwner,
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
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
    filterSiblingChains,
    sendTransaction,
    newRoleStatus,
  });

  // Setup Fast Switchboard2 roles
  await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: socketOwner,
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
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
    filterSiblingChains,
    sendTransaction,
    newRoleStatus,
  });

  // Grant watcher role to watcher for OptimisticSwitchboard
  await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: socketOwner,
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
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
    filterSiblingChains,
    sendTransaction,
    newRoleStatus,
  });
};
