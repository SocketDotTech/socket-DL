import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { ROLES, CORE_CONTRACTS, ChainSlug } from "../../src";
import { mode, overrides, relayers } from "./config";
import constants from "./utils/kinto/constants.json";
import { getAddresses, getInstance, getRoleHash } from "./utils";
import { handleOps, isKinto, whitelistApp } from "./utils/kinto/kinto";
import { Wallet } from "ethers";
import { getProviderFromChainSlug } from "../constants";

// TODO: maybe modify so in the case of the SocketBatcher, we only grant the role to the funding wallet and not to all of them
// since it has the withdrawals function.
const main = async () => {
  const addresses = await getAddresses(constants.KINTO_DATA.chainId, mode);

  const whitelistedContracts = [
    "CapacitorSimulator",
    CORE_CONTRACTS.Socket,
    CORE_CONTRACTS.ExecutionManager,
    CORE_CONTRACTS.TransmitManager,
    // CORE_CONTRACTS.FastSwitchboard, // No need
    CORE_CONTRACTS.OptimisticSwitchboard,
    CORE_CONTRACTS.SocketBatcher,
    "SocketSimulator",
    "SimulatorUtils",
    "SwitchboardSimulator",
  ];

  const contracts = [
    addresses[CORE_CONTRACTS.SocketBatcher],
    addresses[CORE_CONTRACTS.Socket],
    addresses[CORE_CONTRACTS.ExecutionManager],
  ];

  const allAddresses = [...relayers, ...contracts];

  const provider = getProviderFromChainSlug(
    constants.KINTO_DATA.chainId as any as ChainSlug
  );
  const wallet = new Wallet(process.env.SOCKET_SIGNER_KEY!, provider);

  for (const contract of whitelistedContracts) {
    // for each relayer, grant SOCKET_RELAYER_ROLE
    const userSpecificRoles = allAddresses.map((relayer) => ({
      userAddress: relayer,
      filterRoles: [ROLES.SOCKET_RELAYER_ROLE],
    }));
    console.log(`\nWhitelisting ${contract} @ ${addresses[contract]}...`);
    await whitelistApp(
      process.env.SOCKET_OWNER_ADDRESS,
      addresses[contract],
      process.env.SOCKET_SIGNER_KEY
    );

    const instance = (
      await getInstance(
        contract === "CapacitorSimulator" ? "SingleCapacitor" : contract,
        addresses[contract]
      )
    ).connect(wallet);

    for (const role of userSpecificRoles) {
      // check if the role is already granted
      const hasRole = await instance.hasRole(
        getRoleHash(ROLES.SOCKET_RELAYER_ROLE),
        role.userAddress
      );
      if (hasRole) {
        console.log(
          `Role ${role.filterRoles} already granted to ${role.userAddress} on contract ${contract}.`
        );
        continue;
      }
      console.log(
        `Granting ${role.filterRoles} to ${role.userAddress} on contract ${contract}...`
      );
      const txRequest = await instance.populateTransaction.grantRole(
        getRoleHash(ROLES.SOCKET_RELAYER_ROLE),
        role.userAddress,
        {
          ...overrides(await wallet.getChainId()),
        }
      );

      const registerTx = await handleOps(
        process.env.SOCKET_OWNER_ADDRESS,
        [txRequest],
        process.env.SOCKET_SIGNER_KEY
      );
      console.log(
        `- Successfully granted ${role.filterRoles} to ${role.userAddress} on contract ${contract}. Transaction hash: ${registerTx.transactionHash}`
      );
    }
  }

  // add each relayer to the allowlist of the SocketBatcher
  for (const relayer of relayers) {
    const socketBatcher = (
      await getInstance(
        CORE_CONTRACTS.SocketBatcher,
        addresses[CORE_CONTRACTS.SocketBatcher]
      )
    ).connect(wallet);
    // check if the relayer is already in the allowlist
    const isAllowed = await socketBatcher.allowlist(relayer);
    if (isAllowed) {
      console.log(`${relayer} is already in the allowlist of SocketBatcher.`);
      continue;
    }
    const txRequest = await socketBatcher.populateTransaction.updateAllowlist(
      relayer,
      true,
      {
        ...overrides(await wallet.getChainId()),
      }
    );
    const registerTx = await handleOps(
      process.env.SOCKET_OWNER_ADDRESS,
      [txRequest],
      process.env.SOCKET_SIGNER_KEY
    );
    console.log(
      `Successfully added ${relayer} to the allowlist of SocketBatcher. Transaction hash: ${registerTx.transactionHash}`
    );
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
