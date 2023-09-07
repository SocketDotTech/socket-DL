import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import {
  ChainSlug,
  TestnetIds,
  MainnetIds,
  ROLES,
  REQUIRED_ROLES,
  CORE_CONTRACTS,
  ChainSocketAddresses,
  REQUIRED_CHAIN_ROLES,
  IntegrationTypes,
  isTestnet,
  isMainnet,
  getAddresses,
  chainKeyToSlug,
  ChainSlugToKey,
} from "../../src";
import { getRoleHash, getChainRoleHash } from "./utils";
import { Contract, Wallet, ethers } from "ethers";
import { getABI } from "./scripts/getABIs";
import { getProviderFromChainName } from "../constants";
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
import { overrides } from "./config";

let roleStatus: any = {};

interface checkAndUpdateRolesObj {
  userSpecificRoles: { userAddress: string; filterRoles: ROLES[] }[];
  filterChains: ChainSlug[];
  filterSiblingChains: ChainSlug[];
  contractName: CORE_CONTRACTS;
  newRoleStatus: boolean;
  sendTransaction: boolean;
}

// let roleTxns: any;
let roleTxns: {
  [chainId in ChainSlug]?: {
    [contractName: string]: {
      to: string;
      role: string;
      slug: number;
      grantee: string;
    }[];
  };
} = {};

let otherTxns: {
  [chainId in ChainSlug]?: {
    to: string;
    data: string;
  }[];
} = {};

const isRoleChanged = (hasRole: boolean, newRoleStatus: boolean) => {
  return (!hasRole && newRoleStatus) || (hasRole && !newRoleStatus);
};
const addTransaction = (
  chainId: ChainSlug,
  contractName: string,
  contractAddress: string,
  hasRole: boolean,
  role: string,
  slug: number,
  userAddress: string,
  newRoleStatus: boolean
) => {
  if (isRoleChanged(hasRole, newRoleStatus)) {
    if (!roleTxns[chainId]) roleTxns[chainId] = {};
    if (!roleTxns[chainId]![contractName])
      roleTxns[chainId]![contractName] = [];
    roleTxns[chainId]![contractName]?.push({
      to: contractAddress,
      role,
      slug,
      grantee: userAddress,
    });
  }
};

const getRoleTxnData = (
  roles: string[],
  slugs: number[],
  userAddresses: string[],
  type: "GRANT" | "REVOKE"
) => {
  let accessControlInterface = new ethers.utils.Interface(
    getABI["AccessControlExtended"]
  );
  if (type === "GRANT") {
    return accessControlInterface.encodeFunctionData(
      "grantBatchRole(bytes32[],uint32[],address[])",
      [roles, slugs, userAddresses]
    );
  } else if (type === "REVOKE") {
    return accessControlInterface.encodeFunctionData(
      "revokeBatchRole(bytes32[],uint32[],address[])",
      [roles, slugs, userAddresses]
    );
  } else {
    throw Error("Invalid grant type");
  }
};

const executeRoleTransactions = async (
  chainId: ChainSlug,
  newRoleStatus: boolean,
  wallet: Wallet
) => {
  if (!roleTxns[chainId]) return;
  let contracts = Object.keys(roleTxns[chainId]!);
  for (let i = 0; i < contracts.length; i++) {
    let contractSpecificTxns:
      | { to: string; role: string; slug: number; grantee: string }[]
      | undefined = roleTxns[chainId]![contracts[i] as CORE_CONTRACTS];
    if (!contractSpecificTxns?.length) continue;

    let roles: string[] = [],
      slugs: number[] = [],
      addresses: string[] = [];

    let contractAddress: string | undefined;

    contractSpecificTxns!.forEach((roleTx) => {
      contractAddress = roleTx.to;
      if (newRoleStatus) {
        roles.push(roleTx.role);
        slugs.push(roleTx.slug);
        addresses.push(roleTx.grantee);
      } else {
        roles.push(roleTx.role);
        slugs.push(roleTx.slug);
        addresses.push(roleTx.grantee);
      }
    });

    if (!roles.length) continue;
    console.log(chainId, contracts[0], roles.length);
    let data: string;
    if (newRoleStatus) {
      data = getRoleTxnData(roles, slugs, addresses, "GRANT");
    } else {
      data = getRoleTxnData(roles, slugs, addresses, "REVOKE");
    }
    let tx = await wallet.sendTransaction({
      to: contractAddress,
      data,
      ...overrides[chainId],
    });
    console.log(
      `chain: ${chainId}`,
      " contract:",
      contractAddress,
      { newRoleStatus },
      "hash: ",
      tx.hash
    );
    await tx.wait();
  }
};

const executeOtherTransactions = async (chainId: ChainSlug, wallet: Wallet) => {
  if (!otherTxns[chainId as any as keyof typeof otherTxns]) return;

  let txnDatas = otherTxns[chainId as any as keyof typeof otherTxns]!;
  for (let i = 0; i < txnDatas.length; i++) {
    let { to, data } = txnDatas[i];
    let tx = await wallet.sendTransaction({
      to,
      data,
      ...overrides[chainId],
    });
    console.log(`to: ${to}, txHash: ${tx?.hash}`);
    await tx.wait();
    console.log(`txHash: ${tx?.hash} COMPLETE`);
  }
};

const executeTransactions = async (
  activeChainSlugs: ChainSlug[],
  newRoleStatus: boolean
) => {
  await Promise.all(
    activeChainSlugs.map(async (chainId) => {
      let provider = getProviderFromChainName(
        ChainSlugToKey[
          chainId as any as ChainSlug
        ] as keyof typeof chainKeyToSlug
      );
      let wallet = new Wallet(process.env.SOCKET_SIGNER_KEY!, provider);
      await executeRoleTransactions(chainId, newRoleStatus, wallet);
      await executeOtherTransactions(chainId, wallet);
    })
  );
};

const getSiblingSlugs = (chainId: ChainSlug): ChainSlug[] => {
  if (isTestnet(chainId))
    return TestnetIds.filter((chainSlug) => chainSlug !== chainId);
  if (isMainnet(chainId))
    return MainnetIds.filter((chainSlug) => chainSlug !== chainId);
  return [];
};

export const checkNativeSwitchboardRoles = async ({
  chainId,
  provider,
  siblingSlugs,
  addresses,
  filterRoles,
  userAddress,
  newRoleStatus,
}: {
  chainId: ChainSlug;
  siblingSlugs: ChainSlug[];
  provider: any;
  addresses: ChainSocketAddresses | undefined;
  filterRoles: ROLES[];
  userAddress: string;
  newRoleStatus: boolean;
}) => {
  let contractName = CORE_CONTRACTS.NativeSwitchboard;

  await Promise.all(
    siblingSlugs.map(async (siblingSlug) => {
      if (filterChains.length > 0 && !filterChains.includes(siblingSlug))
        return;

      let pseudoContractName = contractName + "_" + String(siblingSlug);
      let contractAddress =
        addresses?.["integrations"]?.[siblingSlug]?.[IntegrationTypes.native]
          ?.switchboard;

      if (!contractAddress) {
        // console.log(
        //   chainId,
        //   siblingSlug,
        //   " address not present: ",
        //   contractName
        // );
        return;
      }
      let instance = new Contract(
        contractAddress,
        getABI[contractName as keyof typeof getABI],
        provider
      );
      let requiredRoles =
        REQUIRED_ROLES[contractName as keyof typeof REQUIRED_ROLES];

      roleStatus[chainId][pseudoContractName] = {};
      await Promise.all(
        requiredRoles.map(async (role) => {
          if (filterRoles.length > 0 && !filterRoles.includes(role)) return;
          let hasRole = await instance.callStatic["hasRole(bytes32,address)"](
            getRoleHash(role),
            userAddress
          );

          if (!roleStatus[chainId][pseudoContractName]["global"])
            roleStatus[chainId][pseudoContractName]["global"] = [];
          if (isRoleChanged(hasRole, newRoleStatus))
            roleStatus[chainId][pseudoContractName]["global"].push({
              hasRole,
              role,
              userAddress,
            });
          addTransaction(
            chainId,
            pseudoContractName,
            contractAddress!,
            hasRole,
            getRoleHash(role),
            0,
            userAddress,
            newRoleStatus
          );
        })
      );
    })
  );
};

let summary: { params: any; roleStatus: any }[] = [];

export const checkAndUpdateRoles = async (params: checkAndUpdateRolesObj) => {
  try {
    let {
      sendTransaction,
      filterChains,
      filterSiblingChains,
      contractName,
      userSpecificRoles,
      newRoleStatus,
    } = params;

    (roleTxns = {}), (otherTxns = {}), (roleStatus = {});
    console.log("================= checking for : ", params);
    let activeChainSlugs =
      filterChains.length > 0 ? filterChains : [...MainnetIds, ...TestnetIds];
    // parallelize chains
    await Promise.all(
      activeChainSlugs.map(async (chainId) => {
        if (filterChains.length > 0 && !filterChains.includes(chainId)) return;
        roleStatus[chainId] = {};
        // roleStatus[chainId]["integrations"] = {};

        let siblingSlugs = getSiblingSlugs(chainId);

        // console.log(chainId, " Sibling Slugs: ", siblingSlugs);

        // console.log(
        //   "============= checking for network: ",
        //   ChainSlugToKey[chainId],
        //   "================="
        // );
        let addresses: ChainSocketAddresses | undefined;
        try {
          addresses = await getAddresses(chainId, mode);
        } catch (error) {
          addresses = undefined;
        }

        if (!addresses) return;
        let provider = getProviderFromChainName(
          ChainSlugToKey[chainId] as keyof typeof chainKeyToSlug
        );

        let contractNames = Object.keys(REQUIRED_ROLES);
        await Promise.all(
          userSpecificRoles.map(async (roleObj) => {
            let { userAddress, filterRoles } = roleObj;
            if (!contractNames.includes(contractName as CORE_CONTRACTS)) return;

            let contractAddress: string | undefined;
            // In case of native switchboard, check for address under integrations->NATIVE_BRIDGE
            if (contractName === CORE_CONTRACTS.NativeSwitchboard) {
              await checkNativeSwitchboardRoles({
                chainId,
                provider,
                siblingSlugs,
                addresses,
                userAddress,
                newRoleStatus,
                filterRoles,
              });
              return;
            }

            //@ts-ignore
            contractAddress =
              addresses?.[contractName as keyof ChainSocketAddresses];

            if (!contractAddress) {
              console.log(chainId, " address not present: ", contractName);
              return;
            }
            let instance = new Contract(
              contractAddress,
              getABI[contractName as keyof typeof getABI],
              provider
            );
            let requiredRoles =
              REQUIRED_ROLES[contractName as keyof typeof REQUIRED_ROLES];

            roleStatus[chainId][contractName!] = {};
            await Promise.all(
              requiredRoles.map(async (role) => {
                if (filterRoles.length > 0 && !filterRoles.includes(role))
                  return;
                let hasRole = await instance.callStatic[
                  "hasRole(bytes32,address)"
                ](getRoleHash(role), userAddress);
                if (isRoleChanged(hasRole, newRoleStatus)) {
                  if (!roleStatus[chainId][contractName!]["global"]) {
                    roleStatus[chainId][contractName!]["global"] = [];
                  }
                  roleStatus[chainId][contractName]["global"].push({
                    hasRole,
                    role,
                    userAddress,
                  });
                }

                // console.log(chainId, contractName, role, hasRole);
                addTransaction(
                  chainId,
                  contractName as CORE_CONTRACTS,
                  contractAddress!,
                  hasRole,
                  getRoleHash(role),
                  0, // keep slug as 0 for non-chain specific roles
                  userAddress,
                  newRoleStatus
                );
              })
            );

            let requiredChainRoles =
              REQUIRED_CHAIN_ROLES[
                contractName as keyof typeof REQUIRED_CHAIN_ROLES
              ];

            if (!requiredChainRoles?.length) return;
            if (
              contractName == CORE_CONTRACTS.TransmitManager &&
              filterRoles.includes(ROLES.TRANSMITTER_ROLE)
            ) {
              siblingSlugs.push(chainId);
            }
            await Promise.all(
              siblingSlugs.map(async (siblingSlug) => {
                if (
                  filterSiblingChains.length > 0 &&
                  !filterSiblingChains.includes(siblingSlug)
                )
                  return;

                await Promise.all(
                  requiredChainRoles.map(async (role) => {
                    if (filterRoles.length > 0 && !filterRoles.includes(role))
                      return;
                    let hasRole = await instance.callStatic[
                      "hasRole(bytes32,address)"
                    ](getChainRoleHash(role, Number(siblingSlug)), userAddress);

                    if (isRoleChanged(hasRole, newRoleStatus)) {
                      if (
                        !roleStatus[chainId][contractName][siblingSlug]?.length
                      )
                        roleStatus[chainId][contractName][siblingSlug] = [];

                      roleStatus[chainId][contractName][siblingSlug].push({
                        role,
                        hasRole,
                        userAddress,
                      });
                    }

                    // console.log(chainId, contractName, role, hasRole);

                    // If Watcher role in FastSwitchboard, have to call another function
                    // to set the role
                    if (
                      contractName === CORE_CONTRACTS.FastSwitchboard &&
                      role === ROLES.WATCHER_ROLE &&
                      isRoleChanged(hasRole, newRoleStatus)
                    ) {
                      let data;
                      if (newRoleStatus) {
                        data = instance.interface.encodeFunctionData(
                          "grantWatcherRole",
                          [siblingSlug, userAddress]
                        );
                      } else {
                        data = instance.interface.encodeFunctionData(
                          "revokeWatcherRole",
                          [siblingSlug, userAddress]
                        );
                      }

                      if (!otherTxns[chainId]) otherTxns[chainId] = [];
                      otherTxns[chainId]?.push({
                        to: instance.address,
                        data,
                      });
                    } else {
                      addTransaction(
                        chainId,
                        contractName as CORE_CONTRACTS,
                        contractAddress!,
                        hasRole,
                        getRoleHash(role),
                        Number(siblingSlug),
                        userAddress,
                        newRoleStatus
                      );
                    }
                  })
                );
              })
            );
          })
        );
      })
    );

    console.log(JSON.stringify(roleStatus));
    console
      .log
      // "send transaction: ",
      // sendTransaction,
      // "roleTxns : ",
      // roleTxns,
      // JSON.stringify(roleTxns)
      // "other txns: ",
      // otherTxns,
      // JSON.stringify(otherTxns)
      ();

    if (sendTransaction)
      await executeTransactions(activeChainSlugs, newRoleStatus);

    summary.push({ params, roleStatus });
  } catch (error) {
    console.log("Error while checking roles", error);
    throw error;
  }
};

const main = async () => {
  let ownerAddress = socketOwner;
  let executorAddress = executorAddresses[mode];
  let transmitterAddress = transmitterAddresses[mode];
  let watcherAddress = watcherAddresses[mode];

  // Grant rescue,withdraw and governance role for Execution Manager to owner
  await checkAndUpdateRoles({
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

  // Grant owner roles for TransmitManager
  await checkAndUpdateRoles({
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

  // Grant owner roles in socket
  await checkAndUpdateRoles({
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

  // Setup Fast Switchboard roles except WATCHER
  await checkAndUpdateRoles({
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

  // Grant watcher role to watcher for OptimisticSwitchboard
  await checkAndUpdateRoles({
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

  // Grant owner roles in NativeSwitchboard
  await checkAndUpdateRoles({
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
