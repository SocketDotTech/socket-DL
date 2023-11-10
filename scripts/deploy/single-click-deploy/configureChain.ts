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
  for (let c = 0; c < filterChains.length; c++) {
    const sibling = filterChains[c] as any as ChainSlug;
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
      CORE_CONTRACTS.FastSwitchboard2,
      IntegrationTypes.fast2,
      addresses[sibling]!,
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
        userAddress: config.feeUpdaterAddress,
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
      {
        userAddress: config.executorAddress,
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
        userAddress: config.feeUpdaterAddress,
        filterRoles: [ROLES.TRANSMITTER_ROLE],
      },
      {
        userAddress: config.transmitterAddress,
        filterRoles: [ROLES.FEES_UPDATER_ROLE],
      },
    ],
    contractName: CORE_CONTRACTS.TransmitManager,
    filterChains,
    filterSiblingChains: [chain],
    sendTransaction,
    newRoleStatus,
  });

  // Setup Fast Switchboard2 roles
  await checkAndUpdateRoles({
    userSpecificRoles: [
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
    filterChains,
    filterSiblingChains: [chain],
    sendTransaction,
    newRoleStatus,
  });

  // Grant watcher role to watcher for OptimisticSwitchboard
  await checkAndUpdateRoles({
    userSpecificRoles: [
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
    filterChains,
    filterSiblingChains: [chain],
    sendTransaction,
    newRoleStatus,
  });
};

main();
