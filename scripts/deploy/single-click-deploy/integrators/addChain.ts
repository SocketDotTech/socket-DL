import { Wallet } from "ethers";
import fs from "fs";

import {
  CORE_CONTRACTS,
  ChainSlug,
  DeploymentAddresses,
  IntegrationTypes,
  ROLES,
} from "../../../../src";
import { checkAndUpdateRoles } from "../../scripts/roles";
import { executionManagerVersion, mode } from "../../config";
import {
  configureExecutionManager,
  registerSwitchboards,
  setManagers,
} from "../../scripts/configureSocket";
import { deployForChains } from "../../scripts/deploySocketFor";
import { RoleOwners, getProviderFromChainSlug } from "../../../constants";
import { deployedAddressPath, storeAllAddresses } from "../../utils";

export const addChain = async (
  chain: ChainSlug,
  siblings: ChainSlug[],
  roleOwners: RoleOwners
) => {
  const addresses = await deployForChains([chain]);
  if (!addresses[chain]) throw new Error("Address not deployed!");

  // grant all roles for new chain
  await grantRoles(chain, siblings, roleOwners);

  const providerInstance = getProviderFromChainSlug(chain as any as ChainSlug);
  const socketSigner: Wallet = new Wallet(
    process.env.SOCKET_SIGNER_KEY as string,
    providerInstance
  );

  // general configs for socket
  await configureExecutionManager(
    executionManagerVersion,
    addresses[chain].ExecutionManager!,
    addresses[chain].SocketBatcher,
    chain,
    siblings,
    socketSigner
  );

  await setManagers(addresses[chain], socketSigner);

  let allAddresses: DeploymentAddresses = JSON.parse(
    fs.readFileSync(deployedAddressPath(mode), "utf-8")
  );

  let addr = await registerSwitchboards(
    chain,
    siblings,
    CORE_CONTRACTS.FastSwitchboard,
    IntegrationTypes.fast,
    addresses[chain],
    allAddresses,
    socketSigner
  );

  allAddresses[chain] = addr;
  await storeAllAddresses(allAddresses, mode);
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
        userAddress: roleOwners.ownerAddress,
        filterRoles: [
          ROLES.RESCUE_ROLE,
          ROLES.GOVERNANCE_ROLE,
          ROLES.WITHDRAW_ROLE,
          ROLES.FEES_UPDATER_ROLE,
        ],
      },
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
    filterChains: [chain],
    filterSiblingChains: siblings,
    sendTransaction: true,
    newRoleStatus: true,
  });

  // Grant owner roles for TransmitManager
  await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: roleOwners.ownerAddress,
        filterRoles: [
          ROLES.RESCUE_ROLE,
          ROLES.GOVERNANCE_ROLE,
          ROLES.WITHDRAW_ROLE,
          ROLES.FEES_UPDATER_ROLE,
        ],
      },
      {
        userAddress: roleOwners.transmitterAddress,
        filterRoles: [ROLES.TRANSMITTER_ROLE],
      },
      {
        userAddress: roleOwners.feeUpdaterAddress,
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
    ],
    contractName: CORE_CONTRACTS.TransmitManager,
    filterChains: [chain],
    filterSiblingChains: siblings,
    sendTransaction: true,
    newRoleStatus: true,
  });

  // Grant owner roles in socket
  await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: roleOwners.ownerAddress,
        filterRoles: [ROLES.RESCUE_ROLE, ROLES.GOVERNANCE_ROLE],
      },
    ],
    contractName: CORE_CONTRACTS.Socket,
    filterChains: [chain],
    filterSiblingChains: siblings,
    sendTransaction: true,
    newRoleStatus: true,
  });

  // Setup Fast Switchboard roles
  await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: roleOwners.ownerAddress,
        filterRoles: [
          ROLES.RESCUE_ROLE,
          ROLES.GOVERNANCE_ROLE,
          ROLES.TRIP_ROLE,
          ROLES.UN_TRIP_ROLE,
          ROLES.WITHDRAW_ROLE,
          ROLES.FEES_UPDATER_ROLE,
        ],
      },
      {
        userAddress: roleOwners.feeUpdaterAddress,
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
      {
        userAddress: roleOwners.watcherAddress,
        filterRoles: [ROLES.WATCHER_ROLE],
      },
    ],

    contractName: CORE_CONTRACTS.FastSwitchboard,
    filterChains: [chain],
    filterSiblingChains: siblings,
    sendTransaction: true,
    newRoleStatus: true,
  });

  // Setup Fast Switchboard2 roles
  await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: roleOwners.ownerAddress,
        filterRoles: [
          ROLES.RESCUE_ROLE,
          ROLES.GOVERNANCE_ROLE,
          ROLES.TRIP_ROLE,
          ROLES.UN_TRIP_ROLE,
          ROLES.WITHDRAW_ROLE,
          ROLES.FEES_UPDATER_ROLE,
        ],
      },
      {
        userAddress: roleOwners.feeUpdaterAddress,
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
      {
        userAddress: roleOwners.watcherAddress,
        filterRoles: [ROLES.WATCHER_ROLE],
      },
    ],

    contractName: CORE_CONTRACTS.FastSwitchboard2,
    filterChains: [chain],
    filterSiblingChains: siblings,
    sendTransaction: true,
    newRoleStatus: true,
  });

  // Grant watcher role to watcher for OptimisticSwitchboard
  await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: roleOwners.ownerAddress,
        filterRoles: [
          ROLES.TRIP_ROLE,
          ROLES.UN_TRIP_ROLE,
          ROLES.RESCUE_ROLE,
          ROLES.GOVERNANCE_ROLE,
          ROLES.FEES_UPDATER_ROLE,
        ],
      },
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
    filterChains: [chain],
    filterSiblingChains: siblings,
    sendTransaction: true,
    newRoleStatus: true,
  });
};
