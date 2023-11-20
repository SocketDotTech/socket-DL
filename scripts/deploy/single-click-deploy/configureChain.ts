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
  executionManagerVersion,
  mode,
  newRoleStatus,
  sendTransaction,
} from "../config";
import {
  configureExecutionManager,
  registerSwitchboards,
} from "../scripts/configureSocket";
import { RoleOwners, getProviderFromChainSlug } from "../../constants";
import { deployedAddressPath, storeAllAddresses } from "../utils";

export const configureChain = async (
  chain: ChainSlug,
  siblings: ChainSlug[],
  roleOwners: RoleOwners
) => {
  const addresses: DeploymentAddresses = JSON.parse(
    fs.readFileSync(deployedAddressPath(mode), "utf-8")
  );

  // grant all roles for new chain
  await grantRoles(chain, siblings, roleOwners);

  let addr;
  for (let c = 0; c < siblings.length; c++) {
    const sibling = siblings[c] as any as ChainSlug;
    const providerInstance = getProviderFromChainSlug(sibling);
    const socketSigner: Wallet = new Wallet(
      process.env.SOCKET_SIGNER_KEY as string,
      providerInstance
    );

    if (!addresses || !addresses[sibling])
      throw new Error(`Sibling addresses not found! ${sibling}`);

    addr = await registerSwitchboards(
      sibling,
      [chain],
      CORE_CONTRACTS.FastSwitchboard,
      IntegrationTypes.fast,
      addresses[sibling]!,
      addresses,
      socketSigner
    );
  }
  await storeAllAddresses(addresses, mode);
};

const grantRoles = async (
  chain: ChainSlug,
  siblings: ChainSlug[],
  roleOwners: RoleOwners
) => {
  if (
    !roleOwners.executorAddress ||
    !roleOwners.transmitterAddress ||
    !roleOwners.watcherAddress ||
    !roleOwners.feeUpdaterAddress ||
    !roleOwners.ownerAddress
  )
    throw new Error("Add all required addresses!");

  // Grant rescue,withdraw and governance role for Execution Manager to owner
  await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: roleOwners.feeUpdaterAddress,
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
      {
        userAddress: roleOwners.executorAddress,
        filterRoles: [ROLES.EXECUTOR_ROLE],
      },
    ],
    contractName: executionManagerVersion,
    filterChains: siblings,
    filterSiblingChains: [chain],
    sendTransaction,
    newRoleStatus,
  });

  // Grant owner roles for TransmitManager
  await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: roleOwners.feeUpdaterAddress,
        filterRoles: [ROLES.TRANSMITTER_ROLE],
      },
      {
        userAddress: roleOwners.transmitterAddress,
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
    ],
    contractName: CORE_CONTRACTS.TransmitManager,
    filterChains: siblings,
    filterSiblingChains: [chain],
    sendTransaction,
    newRoleStatus,
  });

  // Grant watcher role to watcher for OptimisticSwitchboard
  await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: roleOwners.feeUpdaterAddress,
        filterRoles: [ROLES.FEES_UPDATER_ROLE], // all roles
      },
      {
        userAddress: roleOwners.watcherAddress,
        filterRoles: [ROLES.WATCHER_ROLE],
      },
    ],
    contractName: CORE_CONTRACTS.OptimisticSwitchboard,
    filterChains: siblings,
    filterSiblingChains: [chain],
    sendTransaction,
    newRoleStatus,
  });
};
