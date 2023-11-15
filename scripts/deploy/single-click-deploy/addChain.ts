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
import { executionManagerVersion, mode } from "../config";
import {
  configureExecutionManager,
  registerSwitchboards,
  setManagers,
} from "../scripts/configureSocket";
import { deployForChains } from "../scripts/deploySocketFor";
import { getProviderFromChainSlug } from "../../constants";
import { deployedAddressPath, storeAllAddresses } from "../utils";
import { chainConfig } from "../../../chainConfig";

const chain = ChainSlug.SX_NETWORK_TESTNET;
const siblings = [
  ChainSlug.POLYGON_MUMBAI,
  ChainSlug.GOERLI,
  ChainSlug.ARBITRUM_GOERLI,
];

export const main = async () => {
  const addresses = await deployForChains([chain]);
  if (!addresses[chain]) throw new Error("Address not deployed!");

  // grant all roles for new chain
  await grantRoles();

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
        userAddress: config.ownerAddress,
        filterRoles: [
          ROLES.RESCUE_ROLE,
          ROLES.GOVERNANCE_ROLE,
          ROLES.WITHDRAW_ROLE,
          ROLES.FEES_UPDATER_ROLE,
        ],
      },
      {
        userAddress: config.feeUpdaterAddress,
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
      {
        userAddress: config.executorAddress,
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
        userAddress: config.ownerAddress,
        filterRoles: [
          ROLES.RESCUE_ROLE,
          ROLES.GOVERNANCE_ROLE,
          ROLES.WITHDRAW_ROLE,
          ROLES.FEES_UPDATER_ROLE,
        ],
      },
      {
        userAddress: config.transmitterAddress,
        filterRoles: [ROLES.TRANSMITTER_ROLE],
      },
      {
        userAddress: config.feeUpdaterAddress,
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
        userAddress: config.ownerAddress,
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
        userAddress: config.ownerAddress,
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
        userAddress: config.feeUpdaterAddress,
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
      {
        userAddress: config.watcherAddress,
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
        userAddress: config.ownerAddress,
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
        userAddress: config.feeUpdaterAddress,
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
      {
        userAddress: config.watcherAddress,
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
        userAddress: config.ownerAddress,
        filterRoles: [
          ROLES.TRIP_ROLE,
          ROLES.UN_TRIP_ROLE,
          ROLES.RESCUE_ROLE,
          ROLES.GOVERNANCE_ROLE,
          ROLES.FEES_UPDATER_ROLE,
        ],
      },
      {
        userAddress: config.feeUpdaterAddress,
        filterRoles: [ROLES.FEES_UPDATER_ROLE], // all roles
      },
      {
        userAddress: config.watcherAddress,
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

main();
