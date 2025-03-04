import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import {
  ROLES,
  CORE_CONTRACTS,
  ChainSlug,
  DeploymentAddresses,
} from "../../../src";
import {
  mode,
  transmitterAddresses,
  watcherAddresses,
  executorAddresses,
  ownerAddresses,
  hexagateTripRoleOwners,
} from "../config/config";
import { checkAndUpdateRoles } from "./roles";
import { sleep } from "@socket.tech/dl-common";

const sleepTime = 100;
const newRoleStatus = true;

export const configureRoles = async (
  addresses: DeploymentAddresses,
  chains: ChainSlug[],
  siblings: ChainSlug[],
  safeChains: ChainSlug[],
  sendTransaction: boolean,
  executionManagerVersion: CORE_CONTRACTS
) => {
  let executorAddress = executorAddresses[mode];
  let transmitterAddress = transmitterAddresses[mode];
  let watcherAddress = watcherAddresses[mode];
  let signingOwnerAddress = ownerAddresses[mode];
  let hexagateTripRoleOwner = hexagateTripRoleOwners[mode];

  let summary: { params: any; roleStatus: any }[] = [];
  await Promise.all(
    chains.map(async (chain) => {
      let sendingOwnerAddress = safeChains.includes(chain)
        ? addresses[chain]["SocketSafeProxy"]
        : ownerAddresses[mode];
      let s;

      // Grant rescue,withdraw and governance role for Execution Manager to owner
      s = await checkAndUpdateRoles(
        {
          userSpecificRoles: [
            {
              userAddress: signingOwnerAddress,
              filterRoles: [ROLES.FEES_UPDATER_ROLE],
            },
            {
              userAddress: sendingOwnerAddress,
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
          filterChains: [chain],
          filterSiblingChains: siblings,
          safeChains,
          sendTransaction,
          newRoleStatus,
        },
        addresses
      );
      summary.push(s);

      await sleep(sleepTime);

      // Grant owner roles for TransmitManager
      s = await checkAndUpdateRoles(
        {
          userSpecificRoles: [
            {
              userAddress: signingOwnerAddress,
              filterRoles: [ROLES.FEES_UPDATER_ROLE],
            },
            {
              userAddress: sendingOwnerAddress,
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
          filterChains: [chain],
          filterSiblingChains: siblings,
          safeChains,
          sendTransaction,
          newRoleStatus,
        },
        addresses
      );
      summary.push(s);

      await sleep(sleepTime);

      // Grant owner roles in socket
      s = await checkAndUpdateRoles(
        {
          userSpecificRoles: [
            {
              userAddress: sendingOwnerAddress,
              filterRoles: [ROLES.RESCUE_ROLE, ROLES.GOVERNANCE_ROLE],
            },
          ],
          contractName: CORE_CONTRACTS.Socket,
          filterChains: [chain],
          filterSiblingChains: siblings,
          safeChains,
          sendTransaction,
          newRoleStatus,
        },
        addresses
      );
      summary.push(s);

      await sleep(sleepTime);

      // Setup Fast Switchboard roles
      s = await checkAndUpdateRoles(
        {
          userSpecificRoles: [
            {
              userAddress: signingOwnerAddress,
              filterRoles: [
                ROLES.TRIP_ROLE,
                ROLES.UN_TRIP_ROLE,
                ROLES.FEES_UPDATER_ROLE,
              ],
            },
            {
              userAddress: sendingOwnerAddress,
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
              userAddress: hexagateTripRoleOwner,
              filterRoles: [ROLES.TRIP_ROLE],
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
          filterChains: [chain],
          filterSiblingChains: siblings,
          safeChains,
          sendTransaction,
          newRoleStatus,
        },
        addresses
      );
      summary.push(s);

      await sleep(sleepTime);

      // Grant watcher role to watcher for OptimisticSwitchboard
      s = await checkAndUpdateRoles(
        {
          userSpecificRoles: [
            {
              userAddress: signingOwnerAddress,
              filterRoles: [
                ROLES.TRIP_ROLE,
                ROLES.UN_TRIP_ROLE,
                ROLES.FEES_UPDATER_ROLE,
              ],
            },
            {
              userAddress: sendingOwnerAddress,
              filterRoles: [
                ROLES.TRIP_ROLE,
                ROLES.UN_TRIP_ROLE,
                ROLES.RESCUE_ROLE,
                ROLES.GOVERNANCE_ROLE,
                ROLES.FEES_UPDATER_ROLE,
              ],
            },
            {
              userAddress: hexagateTripRoleOwner,
              filterRoles: [ROLES.TRIP_ROLE],
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
          filterChains: [chain],
          filterSiblingChains: siblings,
          safeChains,
          sendTransaction,
          newRoleStatus,
        },
        addresses
      );
      summary.push(s);

      await sleep(sleepTime);

      // Grant owner roles in NativeSwitchboard
      s = await checkAndUpdateRoles(
        {
          userSpecificRoles: [
            {
              userAddress: signingOwnerAddress,
              filterRoles: [
                ROLES.TRIP_ROLE,
                ROLES.UN_TRIP_ROLE,
                ROLES.FEES_UPDATER_ROLE,
              ], // all roles
            },
            {
              userAddress: sendingOwnerAddress,
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
              userAddress: hexagateTripRoleOwner,
              filterRoles: [ROLES.TRIP_ROLE],
            },
            {
              userAddress: transmitterAddress,
              filterRoles: [ROLES.FEES_UPDATER_ROLE], // all roles
            },
          ],
          contractName: CORE_CONTRACTS.NativeSwitchboard,
          filterChains: [chain],
          filterSiblingChains: siblings,
          safeChains,
          sendTransaction,
          newRoleStatus,
        },
        addresses
      );
      summary.push(s);
    })
  );

  console.log(
    "=========================== SUMMARY ================================="
  );
  summary.forEach((result) => {
    console.log("=============================================");
    console.log("params:", result.params);
    console.log("role status: ", JSON.stringify(result.roleStatus));
  });
};
