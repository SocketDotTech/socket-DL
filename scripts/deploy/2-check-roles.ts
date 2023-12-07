import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { ROLES, CORE_CONTRACTS } from "../../src";
import {
  executorAddresses,
  filterChains,
  filterSiblingChains,
  mode,
  newRoleStatus,
  sendTransaction,
  socketOwner,
  transmitterAddresses,
  watcherAddresses,
  executionManagerVersion,
} from "./config";
import { checkAndUpdateRoles } from "./scripts/roles";

const main = async () => {
  let ownerAddress = socketOwner;
  let executorAddress = executorAddresses[mode];
  let transmitterAddress = transmitterAddresses[mode];
  let watcherAddress = watcherAddresses[mode];

  let summary: { params: any; roleStatus: any }[] = [];
  let s;

  // Grant rescue,withdraw and governance role for Execution Manager to owner
  s = await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: ownerAddress,
        filterRoles: [
          ROLES.RESCUE_ROLE,
          ROLES.GOVERNANCE_ROLE,
          ROLES.WITHDRAW_ROLE,
          ROLES.FEES_UPDATER_ROLE,
        ],
      },
      {
        userAddress: transmitterAddress,
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
      {
        userAddress: executorAddress,
        filterRoles: [ROLES.EXECUTOR_ROLE],
      },
    ],
    contractName: executionManagerVersion,
    filterChains,
    filterSiblingChains,
    sendTransaction,
    newRoleStatus,
  });
  summary.push(s);

  // Grant owner roles for TransmitManager
  s = await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: ownerAddress,
        filterRoles: [
          ROLES.RESCUE_ROLE,
          ROLES.GOVERNANCE_ROLE,
          ROLES.WITHDRAW_ROLE,
          ROLES.FEES_UPDATER_ROLE,
        ],
      },
      {
        userAddress: transmitterAddress,
        filterRoles: [ROLES.TRANSMITTER_ROLE, ROLES.FEES_UPDATER_ROLE],
      },
    ],
    contractName: CORE_CONTRACTS.TransmitManager,
    filterChains,
    filterSiblingChains,
    sendTransaction,
    newRoleStatus,
  });
  summary.push(s);

  // Grant owner roles in socket
  s = await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: ownerAddress,
        filterRoles: [ROLES.RESCUE_ROLE, ROLES.GOVERNANCE_ROLE],
      },
    ],
    contractName: CORE_CONTRACTS.Socket,
    filterChains,
    filterSiblingChains,
    sendTransaction,
    newRoleStatus,
  });
  summary.push(s);

  // Setup Fast Switchboard roles
  s = await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: ownerAddress,
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
        userAddress: transmitterAddress,
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
      {
        userAddress: watcherAddress,
        filterRoles: [ROLES.WATCHER_ROLE],
      },
    ],

    contractName: CORE_CONTRACTS.FastSwitchboard,
    filterChains,
    filterSiblingChains,
    sendTransaction,
    newRoleStatus,
  });
  summary.push(s);

  // Grant watcher role to watcher for OptimisticSwitchboard
  s = await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: ownerAddress,
        filterRoles: [
          ROLES.TRIP_ROLE,
          ROLES.UN_TRIP_ROLE,
          ROLES.RESCUE_ROLE,
          ROLES.GOVERNANCE_ROLE,
          ROLES.FEES_UPDATER_ROLE,
        ],
      },
      {
        userAddress: transmitterAddress,
        filterRoles: [ROLES.FEES_UPDATER_ROLE], // all roles
      },
      {
        userAddress: watcherAddress,
        filterRoles: [ROLES.WATCHER_ROLE],
      },
    ],
    contractName: CORE_CONTRACTS.OptimisticSwitchboard,
    filterChains,
    filterSiblingChains,
    sendTransaction,
    newRoleStatus,
  });
  summary.push(s);

  // Grant owner roles in NativeSwitchboard
  s = await checkAndUpdateRoles({
    userSpecificRoles: [
      {
        userAddress: ownerAddress,
        filterRoles: [
          ROLES.TRIP_ROLE,
          ROLES.UN_TRIP_ROLE,
          ROLES.GOVERNANCE_ROLE,
          ROLES.WITHDRAW_ROLE,
          ROLES.RESCUE_ROLE,
          ROLES.FEES_UPDATER_ROLE,
        ], // all roles
      },
      {
        userAddress: transmitterAddress,
        filterRoles: [ROLES.FEES_UPDATER_ROLE], // all roles
      },
    ],
    contractName: CORE_CONTRACTS.NativeSwitchboard,
    filterChains,
    filterSiblingChains,
    sendTransaction,
    newRoleStatus,
  });
  summary.push(s);

  console.log(
    "=========================== SUMMARY ================================="
  );

  summary.forEach((result) => {
    console.log("=============================================");
    console.log("params:", result.params);
    console.log("role status: ", JSON.stringify(result.roleStatus));
  });
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
