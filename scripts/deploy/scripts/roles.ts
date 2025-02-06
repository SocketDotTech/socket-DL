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
  DeploymentAddresses,
  Integrations,
} from "../../../src";
import { getRoleHash, getChainRoleHash, getInstance } from "../utils";
import { ethers } from "ethers";
import { getProviderFromChainSlug } from "../../constants";
import { overrides, socketOwner } from "../config/config";
import AccessControlExtendedABI from "@socket.tech/dl-core/artifacts/abi/AccessControlExtended.json";
import { SocketSigner } from "@socket.tech/dl-common";
import { getSocketSigner } from "../utils/socket-signer";
import { multicall } from "./multicall";

let roleStatus: any = {};

interface checkAndUpdateRolesObj {
  userSpecificRoles: { userAddress: string; filterRoles: ROLES[] }[];
  filterChains: ChainSlug[];
  filterSiblingChains: ChainSlug[];
  safeChains: ChainSlug[];
  contractName: CORE_CONTRACTS;
  newRoleStatus: boolean;
  sendTransaction: boolean;
}

// let roleTxns: any;
let roleTxns: {
  [chainSlug in ChainSlug]?: {
    [contractName: string]: {
      to: string;
      role: string;
      slug: number;
      grantee: string;
    }[];
  };
} = {};

let otherTxns: {
  [chainSlug in ChainSlug]?: {
    to: string;
    data: string;
  }[];
} = {};

const isRoleChanged = (hasRole: boolean, newRoleStatus: boolean) => {
  return (!hasRole && newRoleStatus) || (hasRole && !newRoleStatus);
};

const addTransaction = (
  chainSlug: ChainSlug,
  contractName: string,
  contractAddress: string,
  hasRole: boolean,
  role: string,
  slug: number,
  userAddress: string,
  newRoleStatus: boolean
) => {
  if (!isRoleChanged(hasRole, newRoleStatus)) return;

  if (!roleTxns[chainSlug]) roleTxns[chainSlug] = {};
  if (!roleTxns[chainSlug]![contractName])
    roleTxns[chainSlug]![contractName] = [];

  roleTxns[chainSlug]![contractName]?.push({
    to: contractAddress,
    role,
    slug,
    grantee: userAddress,
  });
};

const getRoleTxnData = (
  roles: string[],
  slugs: number[],
  userAddresses: string[],
  type: "GRANT" | "REVOKE"
) => {
  let accessControlInterface = new ethers.utils.Interface(
    AccessControlExtendedABI
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
  chainSlug: ChainSlug,
  newRoleStatus: boolean,
  socketSigner: SocketSigner
) => {
  if (!roleTxns[chainSlug]) return;
  let contracts = Object.keys(roleTxns[chainSlug]!);
  for (let i = 0; i < contracts.length; i++) {
    let contractSpecificTxns:
      | { to: string; role: string; slug: number; grantee: string }[]
      | undefined = roleTxns[chainSlug]![contracts[i] as CORE_CONTRACTS];
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
    let data: string;
    if (newRoleStatus) {
      data = getRoleTxnData(roles, slugs, addresses, "GRANT");
    } else {
      data = getRoleTxnData(roles, slugs, addresses, "REVOKE");
    }
    const transaction = {
      to: contractAddress,
      data,
      ...(await overrides(chainSlug)),
    };

    const isSubmitted = await socketSigner.isTxHashSubmitted(transaction);
    if (isSubmitted) return;

    const tx = await socketSigner.sendTransaction(transaction);
    console.log(
      `chain: ${chainSlug}`,
      " contract:",
      contractAddress,
      { newRoleStatus },
      "hash: ",
      tx.hash
    );
    await tx.wait();
  }
};

const executeOtherTransactions = async (
  chainSlug: ChainSlug,
  socketSigner: SocketSigner
) => {
  if (!otherTxns[chainSlug as any as keyof typeof otherTxns]) return;

  let txnDatas = otherTxns[chainSlug as any as keyof typeof otherTxns]!;
  for (let i = 0; i < txnDatas.length; i++) {
    let { to, data } = txnDatas[i];

    const transaction = {
      to,
      data,
      ...(await overrides(chainSlug)),
    };

    const isSubmitted = await socketSigner.isTxHashSubmitted(transaction);
    if (isSubmitted) return;

    const tx = await socketSigner.sendTransaction(transaction);
    console.log(`to: ${to}, txHash: ${tx?.hash}`);
    await tx.wait();
    console.log(`txHash: ${tx?.hash} COMPLETE`);
  }
};

const executeTransactions = async (
  activeChainSlugs: ChainSlug[],
  safeChains: ChainSlug[],
  newRoleStatus: boolean,
  allAddresses: DeploymentAddresses
) => {
  await Promise.all(
    activeChainSlugs.map(async (chainSlug) => {
      const relaySigner = await getSocketSigner(
        chainSlug,
        allAddresses[chainSlug],
        safeChains.includes(chainSlug),
        !safeChains.includes(chainSlug)
      );
      await executeRoleTransactions(chainSlug, newRoleStatus, relaySigner);
      await executeOtherTransactions(chainSlug, relaySigner);
    })
  );
};

const getSiblingSlugs = (chainSlug: ChainSlug): ChainSlug[] => {
  if (isTestnet(chainSlug)) return TestnetIds.filter((c) => c !== chainSlug);
  if (isMainnet(chainSlug)) return MainnetIds.filter((c) => c !== chainSlug);
  return [];
};

const checkNativeSwitchboardRoles = async ({
  chainSlug,
  provider,
  siblingSlugs,
  addresses,
  filterRoles,
  userAddress,
  newRoleStatus,
  filterChains,
}: {
  chainSlug: ChainSlug;
  siblingSlugs: ChainSlug[];
  provider: any;
  addresses: ChainSocketAddresses | undefined;
  filterRoles: ROLES[];
  userAddress: string;
  newRoleStatus: boolean;
  filterChains: ChainSlug[];
}) => {
  const contractName = CORE_CONTRACTS.NativeSwitchboard;

  await Promise.all(
    siblingSlugs.map(async (siblingSlug) => {
      if (filterChains.length > 0 && !filterChains.includes(siblingSlug))
        return;

      const pseudoContractName = contractName + "_" + String(siblingSlug);
      const contractAddress =
        addresses?.["integrations"]?.[siblingSlug]?.[IntegrationTypes.native]
          ?.switchboard;
      if (!contractAddress) return;

      const instance = (
        await getInstance("OptimismSwitchboard", contractAddress)
      ).connect(provider);
      const socketBatcherContract = (
        await getInstance("SocketBatcher", addresses.SocketBatcher)
      ).connect(provider);

      const requiredRoles =
        REQUIRED_ROLES[contractName as keyof typeof REQUIRED_ROLES];
      roleStatus[chainSlug][pseudoContractName] = {};

      const calls = [];
      requiredRoles.map((role) => {
        if (filterRoles.length > 0 && !filterRoles.includes(role)) return;
        if (!roleStatus[chainSlug][pseudoContractName]["global"])
          roleStatus[chainSlug][pseudoContractName]["global"] = [];

        calls.push({
          target: instance.address,
          callData: instance.interface.encodeFunctionData(
            "hasRole(bytes32,address)",
            [getRoleHash(role), userAddress]
          ),
        });
      });
      const result = await multicall(socketBatcherContract, calls);

      requiredRoles.map(async (role) => {
        if (filterRoles.length > 0 && !filterRoles.includes(role)) return;

        const callIndex = calls.findIndex(
          (c) =>
            c.callData ===
            instance.interface.encodeFunctionData("hasRole(bytes32,address)", [
              getRoleHash(role),
              userAddress,
            ])
        );
        if (callIndex === -1) throw Error("Role not found!");

        const hasRole =
          result[callIndex] ===
          "0x0000000000000000000000000000000000000000000000000000000000000000"
            ? false
            : true;
        if (isRoleChanged(hasRole, newRoleStatus))
          roleStatus[chainSlug][pseudoContractName]["global"].push({
            hasRole,
            role,
            userAddress,
          });

        addTransaction(
          chainSlug,
          pseudoContractName,
          contractAddress!,
          hasRole,
          getRoleHash(role),
          0,
          userAddress,
          newRoleStatus
        );
      });
    })
  );
};

export const checkAndUpdateRoles = async (
  params: checkAndUpdateRolesObj,
  allAddresses: DeploymentAddresses
): Promise<{ params: checkAndUpdateRolesObj; roleStatus: any }> => {
  try {
    let {
      sendTransaction,
      filterChains,
      filterSiblingChains,
      safeChains,
      contractName,
      userSpecificRoles,
      newRoleStatus,
    } = params;

    let contractNames = Object.keys(REQUIRED_ROLES);
    if (!contractNames.includes(contractName as CORE_CONTRACTS)) return;

    (roleTxns = {}), (otherTxns = {}), (roleStatus = {});
    console.log("================= checking for : ", params);

    let activeChainSlugs =
      filterChains.length > 0 ? filterChains : [...MainnetIds, ...TestnetIds];

    // parallelize chains
    await Promise.all(
      activeChainSlugs.map(async (chainSlug) => {
        if (filterChains.length > 0 && !filterChains.includes(chainSlug))
          return;

        const addresses = allAddresses[chainSlug];
        if (!addresses) return;

        roleStatus[chainSlug] = {};

        const provider = getProviderFromChainSlug(
          chainSlug as any as ChainSlug
        );

        // In case of native switchboard, check for address under integrations->NATIVE_BRIDGE
        if (contractName === CORE_CONTRACTS.NativeSwitchboard) {
          const siblingSlugs = getSiblingSlugs(chainSlug);

          for (let index = 0; index < userSpecificRoles.length; index++) {
            let { userAddress, filterRoles } = userSpecificRoles[index];
            if (safeChains.includes(chainSlug))
              userAddress = addresses["SocketSafeProxy"];
            await checkNativeSwitchboardRoles({
              chainSlug,
              provider,
              siblingSlugs,
              addresses,
              userAddress,
              newRoleStatus,
              filterRoles,
              filterChains,
            });
          }

          return;
        }

        let contractAddress: string | number | Integrations =
          addresses?.[contractName as keyof ChainSocketAddresses];
        if (!contractAddress) {
          console.log(chainSlug, " address not present: ", contractName);
          return;
        }

        const instance = (
          await getInstance(contractName, contractAddress as string)
        ).connect(provider);
        const socketBatcherContract = (
          await getInstance("SocketBatcher", addresses.SocketBatcher)
        ).connect(provider);

        const requiredRoles =
          REQUIRED_ROLES[contractName as keyof typeof REQUIRED_ROLES];
        const requiredChainRoles =
          REQUIRED_CHAIN_ROLES[
            contractName as keyof typeof REQUIRED_CHAIN_ROLES
          ];
        roleStatus[chainSlug][contractName!] = {};

        const chainCalls = [];
        const siblingChainCalls = [];

        userSpecificRoles.map(async (roleObj) => {
          let { userAddress, filterRoles } = roleObj;
          if (safeChains.includes(chainSlug))
            userAddress = addresses["SocketSafeProxy"];
          const siblingSlugs = getSiblingSlugs(chainSlug);

          requiredRoles.map(async (role) => {
            if (filterRoles.length > 0 && !filterRoles.includes(role)) return;
            chainCalls.push({
              target: instance.address,
              callData: instance.interface.encodeFunctionData(
                "hasRole(bytes32,address)",
                [getRoleHash(role), userAddress]
              ),
            });
          });

          if (!requiredChainRoles?.length) return;
          if (
            contractName == CORE_CONTRACTS.TransmitManager &&
            filterRoles.includes(ROLES.TRANSMITTER_ROLE)
          ) {
            siblingSlugs.push(chainSlug);
          }

          siblingSlugs.map(async (siblingSlug) => {
            if (
              filterSiblingChains.length > 0 &&
              !filterSiblingChains.includes(siblingSlug)
            )
              return;
            requiredChainRoles.map(async (role) => {
              if (filterRoles.length > 0 && !filterRoles.includes(role)) return;

              siblingChainCalls.push({
                target: instance.address,
                callData: instance.interface.encodeFunctionData(
                  "hasRole(bytes32,address)",
                  [getChainRoleHash(role, Number(siblingSlug)), userAddress]
                ),
              });
            });
          });
        });

        const chainRoles = await multicall(socketBatcherContract, chainCalls);
        const siblingChainRoles = await multicall(
          socketBatcherContract,
          siblingChainCalls
        );

        userSpecificRoles.map(async (roleObj) => {
          let { userAddress, filterRoles } = roleObj;
          if (safeChains.includes(chainSlug))
            userAddress = addresses["SocketSafeProxy"];

          const siblingSlugs = getSiblingSlugs(chainSlug);

          requiredRoles.map(async (role) => {
            if (filterRoles.length > 0 && !filterRoles.includes(role)) return;
            const callIndex = chainCalls.findIndex(
              (c) =>
                c.callData ===
                instance.interface.encodeFunctionData(
                  "hasRole(bytes32,address)",
                  [getRoleHash(role), userAddress]
                )
            );
            if (callIndex === -1) throw Error("Role not found!");
            const hasRole =
              chainRoles[callIndex] ===
              "0x0000000000000000000000000000000000000000000000000000000000000000"
                ? false
                : true;

            if (isRoleChanged(hasRole, newRoleStatus)) {
              if (!roleStatus[chainSlug][contractName!]["global"]) {
                roleStatus[chainSlug][contractName!]["global"] = [];
              }

              roleStatus[chainSlug][contractName]["global"].push({
                hasRole,
                role,
                userAddress,
              });
            }

            addTransaction(
              chainSlug,
              contractName as CORE_CONTRACTS,
              contractAddress! as string,
              hasRole,
              getRoleHash(role),
              0, // keep slug as 0 for non-chain specific roles
              userAddress,
              newRoleStatus
            );
          });

          if (!requiredChainRoles?.length) return;
          if (
            contractName == CORE_CONTRACTS.TransmitManager &&
            filterRoles.includes(ROLES.TRANSMITTER_ROLE)
          ) {
            siblingSlugs.push(chainSlug);
          }

          siblingSlugs.map(async (siblingSlug) => {
            if (
              filterSiblingChains.length > 0 &&
              !filterSiblingChains.includes(siblingSlug)
            )
              return;

            requiredChainRoles.map(async (role) => {
              if (filterRoles.length > 0 && !filterRoles.includes(role)) return;

              const callIndex = siblingChainCalls.findIndex(
                (c) =>
                  c.callData ===
                  instance.interface.encodeFunctionData(
                    "hasRole(bytes32,address)",
                    [getChainRoleHash(role, Number(siblingSlug)), userAddress]
                  )
              );
              if (callIndex === -1)
                throw Error(
                  `Role not found!, ${getChainRoleHash(
                    role,
                    Number(siblingSlug)
                  )}, ${userAddress}, ${siblingSlug}, ${role}`
                );

              const hasRole =
                siblingChainRoles[callIndex] ===
                "0x0000000000000000000000000000000000000000000000000000000000000000"
                  ? false
                  : true;

              if (isRoleChanged(hasRole, newRoleStatus)) {
                if (!roleStatus[chainSlug][contractName][siblingSlug]?.length)
                  roleStatus[chainSlug][contractName][siblingSlug] = [];

                roleStatus[chainSlug][contractName][siblingSlug].push({
                  role,
                  hasRole,
                  userAddress,
                });
              }

              // If Watcher role in FastSwitchboard, have to call another function
              // to set the role
              if (
                (contractName === CORE_CONTRACTS.FastSwitchboard ||
                  contractName === CORE_CONTRACTS.FastSwitchboard2) &&
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

                if (!otherTxns[chainSlug]) otherTxns[chainSlug] = [];
                otherTxns[chainSlug]?.push({
                  to: instance.address,
                  data,
                });
              } else {
                addTransaction(
                  chainSlug,
                  contractName as CORE_CONTRACTS,
                  contractAddress! as string,
                  hasRole,
                  getRoleHash(role),
                  Number(siblingSlug),
                  userAddress,
                  newRoleStatus
                );
              }
            });
          });
        });
      })
    );

    if (sendTransaction)
      await executeTransactions(
        activeChainSlugs,
        safeChains,
        newRoleStatus,
        allAddresses
      );

    return { params, roleStatus };
  } catch (error) {
    console.log("Error while checking roles", error);
    throw error;
  }
};
