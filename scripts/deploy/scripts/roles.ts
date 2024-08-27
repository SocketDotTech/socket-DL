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
import { overrides } from "../config/config";
import AccessControlExtendedABI from "@socket.tech/dl-core/artifacts/abi/AccessControlExtended.json";
import { SocketSigner } from "@socket.tech/dl-common";
import { getSocketSigner } from "../utils/socket-signer";
import { multicall } from "./multicall";

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
    console.log(chainSlug, contracts[0], roles.length);
    let data: string;
    if (newRoleStatus) {
      data = getRoleTxnData(roles, slugs, addresses, "GRANT");
    } else {
      data = getRoleTxnData(roles, slugs, addresses, "REVOKE");
    }
    let tx = await socketSigner.sendTransaction({
      to: contractAddress,
      data,
      ...overrides(chainSlug),
    });
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
    let tx = await socketSigner.sendTransaction({
      to,
      data,
      ...overrides(chainSlug),
    });
    console.log(`to: ${to}, txHash: ${tx?.hash}`);
    await tx.wait();
    console.log(`txHash: ${tx?.hash} COMPLETE`);
  }
};

const executeTransactions = async (
  activeChainSlugs: ChainSlug[],
  newRoleStatus: boolean,
  allAddresses: DeploymentAddresses
) => {
  await Promise.all(
    activeChainSlugs.map(async (chainSlug) => {
      const relaySigner = await getSocketSigner(
        chainSlug,
        allAddresses[chainSlug]
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
          calldata: instance.encodeFunctionData("hasRole(bytes32,address)", [
            getRoleHash(role),
            userAddress,
          ]),
        });
      });
      const result = await multicall(socketBatcherContract, calls);

      requiredRoles.map(async (role, index) => {
        if (isRoleChanged(result[index], newRoleStatus))
          roleStatus[chainSlug][pseudoContractName]["global"].push({
            hasRole: result[index],
            role,
            userAddress,
          });

        addTransaction(
          chainSlug,
          pseudoContractName,
          contractAddress!,
          result[index],
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

        const siblingSlugs = getSiblingSlugs(chainSlug);
        const provider = getProviderFromChainSlug(
          chainSlug as any as ChainSlug
        );

        // In case of native switchboard, check for address under integrations->NATIVE_BRIDGE
        if (contractName === CORE_CONTRACTS.NativeSwitchboard) {
          for (let index = 0; index < userSpecificRoles.length; index++) {
            let { userAddress, filterRoles } = userSpecificRoles[index];
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
          if (filterRoles.length == 0) filterRoles = requiredRoles;
          if (filterSiblingChains.length == 0)
            filterSiblingChains = siblingSlugs;

          filterRoles.map(async (role) => {
            chainCalls.push({
              target: instance.address,
              calldata: instance.encodeFunctionData(
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

          filterSiblingChains.map(async (siblingSlug) => {
            filterRoles.map(async (role) => {
              siblingChainCalls.push({
                target: instance.address,
                calldata: instance.encodeFunctionData(
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
          if (filterRoles.length == 0) filterRoles = requiredRoles;
          if (filterSiblingChains.length == 0)
            filterSiblingChains = siblingSlugs;

          filterRoles.map(async (role, index) => {
            if (isRoleChanged(chainRoles[index], newRoleStatus)) {
              if (!roleStatus[chainSlug][contractName!]["global"]) {
                roleStatus[chainSlug][contractName!]["global"] = [];
              }
              roleStatus[chainSlug][contractName]["global"].push({
                hasRole: chainRoles[index],
                role,
                userAddress,
              });
            }

            addTransaction(
              chainSlug,
              contractName as CORE_CONTRACTS,
              contractAddress! as string,
              chainRoles[index],
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

          filterSiblingChains.map(async (siblingSlug) => {
            requiredChainRoles.map(async (role, index) => {
              if (isRoleChanged(siblingChainRoles[index], newRoleStatus)) {
                if (!roleStatus[chainSlug][contractName][siblingSlug]?.length)
                  roleStatus[chainSlug][contractName][siblingSlug] = [];

                roleStatus[chainSlug][contractName][siblingSlug].push({
                  role,
                  hasRole: siblingChainRoles[index],
                  userAddress,
                });
              }

              // If Watcher role in FastSwitchboard, have to call another function
              // to set the role
              if (
                (contractName === CORE_CONTRACTS.FastSwitchboard ||
                  contractName === CORE_CONTRACTS.FastSwitchboard2) &&
                role === ROLES.WATCHER_ROLE &&
                isRoleChanged(siblingChainRoles[index], newRoleStatus)
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
                  siblingChainRoles[index],
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

    console.log(JSON.stringify(roleStatus));
    if (sendTransaction)
      await executeTransactions(activeChainSlugs, newRoleStatus, allAddresses);

    return { params, roleStatus };
  } catch (error) {
    console.log("Error while checking roles", error);
    throw error;
  }
};
