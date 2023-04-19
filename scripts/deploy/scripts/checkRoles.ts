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
} from "../../../src";
import {
  executorAddress,
  transmitterAddress,
  sealGasLimit,
} from "../../constants/config";
import { getAddresses, getRoleHash, getChainRoleHash } from "../utils";
import { Contract, Wallet, ethers } from "ethers";
import { getABI } from "./getABIs";
import {
  chainSlugs,
  getProviderFromChainName,
  networkToChainSlug,
} from "../../constants";
import { Provider } from "@ethersproject/abstract-provider";

// const userAddress = "0xb3ce44d09862a04dd27d5fc1eb33371db1c5918e";
// Enter roles which are required for testing. Leave empty if want to check all roles.
// let filterRoles = [ROLES.TRANSMITTER_ROLE];
// Enter chains which are required for testing. Leave empty if want to check for all chains.
// let filterChains = [ChainSlug.MUMBAI];
// make this true if wish to include switchboards of integrations
// let includeSwitchboard = false;
// make this true if want to send transaction. if False, will only report about the status
// let sendTransaction = false;
// true for GRANTING, false for REVOKING. use this with sendTransaction=true for granting
// and revoking multiple roles.
// let newRoleStatus = false;

let roleStatus: any = {};

interface checkAndUpdateRolesObj {
  userAddress:string, 
  filterRoles:ROLES[],
  filterChains:ChainSlug[], 
  filterContracts:CORE_CONTRACTS[], 
  includeSwitchboard:boolean, 
  newRoleStatus:boolean, 
  sendTransaction:boolean
}

// let txns: any;

let txns: {
    [chainId in ChainSlug]?: {
      [contractName in CORE_CONTRACTS]?: {
        to: string; 
        role: string;
        grantee:string;
      }[] 
    } 
  } = {};

const addTransaction = (
  chainId: ChainSlug,
  contractName:CORE_CONTRACTS,
  contractAddress: string,
  hasRole: boolean,
  role: string,
  userAddress:string,
  newRoleStatus:boolean
) => {

  if (
    (hasRole === false && newRoleStatus === true) || 
    (hasRole === true && newRoleStatus === false)
  ) {
    if (!txns[chainId]) txns[chainId] = {};
    if (!txns[chainId]![contractName]) txns[chainId]![contractName] = [];
    txns[chainId]![contractName]?.push({ to: contractAddress, role, grantee:userAddress });
  }
};

const getRoleTxnData = (roles:string[], userAddresses:string[], type:"GRANT" | "REVOKE") => {
  let accessControlInterface = new ethers.utils.Interface(getABI["AccessControlExtended"]);
  if (type==="GRANT") {
    return accessControlInterface.encodeFunctionData(
      "grantBatchRole(bytes32[],address[])",
      [roles, userAddresses]
    )
  } else if (type==="REVOKE") {
    return accessControlInterface.encodeFunctionData(
      "revokeBatchRole(bytes32[],address[])",
      [roles, userAddresses]
    )
  } else {
    throw Error("Invalid grant type")
  }
}

const executeTransactions = async (newRoleStatus:boolean) => {
  await Promise.all(
    Object.keys(txns).map(async (chainId) => {
      let provider = getProviderFromChainName(
        networkToChainSlug[
          chainId as any as ChainSlug
        ] as keyof typeof chainSlugs
      );
      let wallet = new Wallet(process.env.ROLE_ASSIGNER_PRIVATE_KEY!, provider);

      if (!txns[chainId as any as keyof typeof txns]) return;
      let contracts = Object.keys(txns[chainId as any as keyof typeof txns]!);
      for (let i=0; i<contracts.length; i++) {

        let contractSpecificTxns:{to:string, role:string, grantee:string}[] | undefined = txns[chainId as any as keyof typeof txns]![contracts[i] as CORE_CONTRACTS];
        if (!contractSpecificTxns?.length) continue;
        
        let grantRoles:string[] = [], grantAddresses:string[] = [];
        let revokeRoles:string[] = [], revokeAddresses: string[] = [];
        let contractAddress:string | undefined;

        contractSpecificTxns!.forEach(roleTx => {
          contractAddress = roleTx.to;
          if (newRoleStatus) {
            grantRoles.push(roleTx.role);
            grantAddresses.push(roleTx.grantee);
          } else {
            revokeRoles.push(roleTx.role);
            revokeAddresses.push(roleTx.grantee);
          }
        });

        if (grantRoles.length) {
          let data = getRoleTxnData(grantRoles, grantAddresses, "GRANT");
          let tx = await wallet.sendTransaction({
            to: contractAddress,
            data,
          });
          console.log(`chain: ${chainId}`, "Grant, contract:", contractAddress, "hash: ", tx.hash);
        }

        if (revokeRoles.length) {
          let data = getRoleTxnData(grantRoles, grantAddresses, "REVOKE");
          let tx = await wallet.sendTransaction({
            to: contractAddress,
            data,
          });
          console.log(`chain: ${chainId}`, "revoke, contract:", contractAddress, "hash: ", tx.hash);
        }
      }
    })
  );
};


// const executeTransactions = async () => {
//   await Promise.all(
//     Object.keys(txns).map(async (chainId: any) => {
//       let provider = getProviderFromChainName(
//         networkToChainSlug[
//           chainId as any as ChainSlug
//         ] as keyof typeof chainSlugs
//       );
//       let wallet = new Wallet(process.env.ROLE_ASSIGNER_PRIVATE_KEY!, provider);

//       let txnData;
//       for (let i = 0; i < txns[chainId as keyof typeof txns]!.length; i++) {
//         try {
//           txnData = txns[chainId as keyof typeof txns]![i];
//           let tx = await wallet.sendTransaction({
//             to: txnData?.to,
//             data: txnData?.data,
//           });
//           console.log(`chain: ${chainId}`, txnData?.to, tx.hash);
//           // await tx.wait();
//         } catch (error) {
//           console.log(chainId, txnData, error);
//         }
//       }
//     })
//   );
// };
const checkSwitchBoardRoles = async (
  contractName: string,
  contractAddress: string,
  chainId: number,
  integrationChainId: number,
  provider: Provider,
  filterRoles:ROLES[],
  userAddress:string,
  newRoleStatus:boolean,
  sendTransaction:boolean
) => {
  let instance = new Contract(
    contractAddress,
    getABI[contractName as keyof typeof getABI],
    provider
  );
  let requiredRoles =
    REQUIRED_ROLES[contractName as keyof typeof REQUIRED_ROLES];
  let requiredChainRoles =
    REQUIRED_CHAIN_ROLES[contractName as keyof typeof REQUIRED_CHAIN_ROLES];

  roleStatus[chainId]["integrations"][integrationChainId][contractName] = {};

  console.log(
    `checking ${chainId} integration ${integrationChainId} ${contractName}`
  );
  await Promise.all(
    requiredRoles.map(async (role) => {
      if (filterRoles.length > 0 && !filterRoles.includes(role)) return;
      let hasRole = await instance.callStatic["hasRole(bytes32,address)"](
        getRoleHash(role),
        userAddress
      );
      roleStatus[chainId]["integrations"][integrationChainId][contractName][
        role
      ] = hasRole;
      addTransaction(
        chainId,
        contractName as CORE_CONTRACTS,
        contractAddress,
        hasRole,
        getRoleHash(role),
        userAddress, 
        newRoleStatus
      );
    })
  );

  console.log(
    `checking ${chainId} integration ${integrationChainId} ${contractName} chain specific`
  );

  if (requiredChainRoles?.length)
    await Promise.all(
      requiredChainRoles.map(async (role) => {
        if (filterRoles.length > 0 && !filterRoles.includes(role)) return;
        let hasRole = await instance.callStatic["hasRole(bytes32,address)"](
          getChainRoleHash(role, Number(integrationChainId)),
          userAddress
        );
        roleStatus[chainId]["integrations"][integrationChainId][contractName][
          role + "_WITH_SLUG"
        ] = hasRole;
        addTransaction(
          chainId,
          contractName as CORE_CONTRACTS,
          contractAddress,
          hasRole,
          getChainRoleHash(role, Number(integrationChainId)),
          userAddress, 
          newRoleStatus
        );
      })
    );
};

export const checkAndUpdateRoles = async (params:checkAndUpdateRolesObj) => {
  try {
    let {userAddress, sendTransaction, filterChains, filterContracts, filterRoles, includeSwitchboard, newRoleStatus} = params;
    // parallelize chains
    await Promise.all(
      [...MainnetIds, ...TestnetIds].map(async (chainId) => {
        if (filterChains.length > 0 && !filterChains.includes(chainId)) return;
        roleStatus[chainId] = {};
        roleStatus[chainId]["integrations"] = {};

        let siblingSlugs:ChainSlug[] = [];
        if (isTestnet(chainId)) siblingSlugs = TestnetIds.filter((chainSlug) => chainSlug!==chainId);
        if (isMainnet(chainId)) siblingSlugs = MainnetIds.filter((chainSlug) => chainSlug!==chainId);
        console.log(chainId, " Sibling Slugs: ", siblingSlugs);

        console.log(
          "checking for network: ",
          networkToChainSlug[chainId],
          "================="
        );
        let addresses = await getAddresses(chainId);

        let integrations = addresses?.integrations;
        let integrationChainIds = integrations ? Object.keys(integrations) : [];
        // console.log(addresses);
        let provider = getProviderFromChainName(
          networkToChainSlug[chainId] as keyof typeof chainSlugs
        );
        console.log("checking integration switchboard roles...............");

        if (includeSwitchboard)
          await Promise.all(
            integrationChainIds.map(async (integrationChainId) => {
              roleStatus[chainId]["integrations"][integrationChainId] = {};
              let nativeSwitchboard =
                integrations![Number(integrationChainId) as ChainSlug]?.[
                  IntegrationTypes.native
                ]?.switchboard;
              let fastSwitchboard =
                integrations![Number(integrationChainId) as ChainSlug]?.[
                  IntegrationTypes.fast
                ]?.switchboard;
              let optimisticSwitchboard =
                integrations![Number(integrationChainId) as ChainSlug]?.[
                  IntegrationTypes.optimistic
                ]?.switchboard;

              let contractName;
              if (fastSwitchboard) {
                contractName = "FastSwitchboard";
                await checkSwitchBoardRoles(
                  contractName,
                  fastSwitchboard,
                  chainId,
                  Number(integrationChainId),
                  provider,
                  filterRoles, 
                  userAddress, 
                  newRoleStatus, 
                  sendTransaction
                );
              } else
                console.log(
                  "fast switchboard not found for integration chain Id: ",
                  integrationChainId
                );
              if (optimisticSwitchboard) {
                contractName = "OptimisticSwitchboard";
                await checkSwitchBoardRoles(
                  contractName,
                  optimisticSwitchboard,
                  chainId,
                  Number(integrationChainId),
                  provider,
                  filterRoles, 
                  userAddress, 
                  newRoleStatus, 
                  sendTransaction
                );
              } else
                console.log(
                  "optimistic switchboard not found for integration chain Id: ",
                  integrationChainId
                );
              if (nativeSwitchboard) {
                contractName = "NativeSwitchboard";
                await checkSwitchBoardRoles(
                  contractName,
                  nativeSwitchboard,
                  chainId,
                  Number(integrationChainId),
                  provider,
                  filterRoles, 
                  userAddress, 
                  newRoleStatus, 
                  sendTransaction
                );
              } else
                console.log(
                  `${chainId} native switchboard not found for integration chain Id: `,
                  integrationChainId
                );
            })
          );

        await Promise.all(
          Object.keys(REQUIRED_ROLES).map(async (contractName) => {
            // Handled Switchboard roles already 
            if (contractName.includes("Switchboard")) return;

            if (
              filterContracts.length>0 && 
              !filterContracts.includes(contractName as  CORE_CONTRACTS)
            ) return;
            roleStatus[chainId][contractName] = {};

            let contractAddress = addresses?.[
              contractName as keyof ChainSocketAddresses
            ] as string;
            if (!contractAddress) {
              console.log("address not present", contractName);
              return;
            }
            let instance = new Contract(
              contractAddress,
              getABI[contractName as keyof typeof getABI],
              provider
            );
            let requiredRoles =
              REQUIRED_ROLES[contractName as keyof typeof REQUIRED_ROLES];
            let requiredChainRoles =
              REQUIRED_CHAIN_ROLES[
                contractName as keyof typeof REQUIRED_CHAIN_ROLES
              ];

            await Promise.all(
              requiredRoles.map(async (role) => {
                if (filterRoles.length > 0 && !filterRoles.includes(role))
                  return;
                let hasRole = await instance.callStatic[
                  "hasRole(bytes32,address)"
                ](getRoleHash(role), userAddress);
                roleStatus[chainId][contractName][role] = hasRole;
                // console.log(chainId, contractName, role, hasRole);
                addTransaction(
                  chainId,
                  contractName as CORE_CONTRACTS,
                  contractAddress,
                  hasRole,
                  getRoleHash(role),
                  userAddress, 
                  newRoleStatus
                );
              })
            );

            if (requiredChainRoles?.length)
              await Promise.all(
                siblingSlugs.map(async (siblingSlug) => {
                  roleStatus[chainId][contractName][siblingSlug] = {};

                  await Promise.all(
                    requiredChainRoles.map(async (role) => {
                      if (filterRoles.length > 0 && !filterRoles.includes(role))
                        return;
                      let hasRole = await instance.callStatic[
                        "hasRole(bytes32,address)"
                      ](
                        getChainRoleHash(role, Number(siblingSlug)),
                        userAddress
                      );
                      roleStatus[chainId][contractName][siblingSlug][
                        role
                      ] = hasRole;
                      console.log(chainId, contractName, role, hasRole);
                      addTransaction(
                        chainId,
                        contractName as CORE_CONTRACTS,
                        contractAddress,
                        hasRole,
                        getChainRoleHash(role, Number(siblingSlug)),
                        userAddress, 
                        newRoleStatus
                      );
                    })
                  );
                })
              );
          })
        );
      })
    );

    console.log(roleStatus, JSON.stringify(roleStatus));
    console.log("send transaction: ", sendTransaction,"txns : ", txns, JSON.stringify(txns));
    
    if (sendTransaction) await executeTransactions(newRoleStatus);
  } catch (error) {
    console.log("Error while checking roles", error);
    throw error;
  }
};


const main = async () => {

  let ownerAddress= "0xb3ce44d09862a04dd27d5fc1eb33371db1c5918e";
  let executorAddress = "0xb3ce44d09862a04dd27d5fc1eb33371db1c5918e";
  let transmitterAddress = "0xb3ce44d09862a04dd27d5fc1eb33371db1c5918e";
  // Grant rescue and governance role for GasPriceOracle
  await checkAndUpdateRoles({
    userAddress:ownerAddress,
    filterRoles:[ROLES.RESCUE_ROLE, ROLES.GOVERNANCE_ROLE],
    filterContracts:[CORE_CONTRACTS.GasPriceOracle],
    filterChains:[ChainSlug.GOERLI],
    sendTransaction:false,
    includeSwitchboard:false,
    newRoleStatus:true
  });

  
  await checkAndUpdateRoles({
    userAddress:ownerAddress,
    filterRoles:[ROLES.RESCUE_ROLE, ROLES.GOVERNANCE_ROLE, ROLES.WITHDRAW_ROLE],
    filterContracts:[CORE_CONTRACTS.ExecutionManager],
    filterChains:[ChainSlug.GOERLI],
    sendTransaction:false,
    includeSwitchboard:false,
    newRoleStatus:true
  })
  // Think about this one. How to handle separate address per network 
  await checkAndUpdateRoles({
    userAddress:executorAddress,
    filterRoles:[ROLES.EXECUTOR_ROLE],
    filterContracts:[CORE_CONTRACTS.ExecutionManager],
    filterChains:[ChainSlug.GOERLI],
    sendTransaction:false,
    includeSwitchboard:false,
    newRoleStatus:true
  })

  await checkAndUpdateRoles({
    userAddress:ownerAddress,
    filterRoles:[ROLES.RESCUE_ROLE, ROLES.GOVERNANCE_ROLE, ROLES.WITHDRAW_ROLE],
    filterContracts:[CORE_CONTRACTS.TransmitManager],
    filterChains:[ChainSlug.GOERLI],
    sendTransaction:false,
    includeSwitchboard:false,
    newRoleStatus:true
  });

  // Think about this one
  await checkAndUpdateRoles({
    userAddress:transmitterAddress,
    filterRoles:[ROLES.GAS_LIMIT_UPDATER_ROLE, ROLES.TRANSMITTER_ROLE],
    filterContracts:[CORE_CONTRACTS.TransmitManager],
    filterChains:[ChainSlug.GOERLI],
    sendTransaction:false,
    includeSwitchboard:false,
    newRoleStatus:true
  });

  await checkAndUpdateRoles({
    userAddress:ownerAddress,
    filterRoles:[ROLES.RESCUE_ROLE, ROLES.GOVERNANCE_ROLE],
    filterContracts:[CORE_CONTRACTS.Socket],
    filterChains:[ChainSlug.GOERLI],
    sendTransaction:false,
    includeSwitchboard:false,
    newRoleStatus:true
  });

}


main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

// let result = {
//   "5": {
//     TransmitManager: {
//       EXECUTOR_ROLE: false,
//       "80001": {
//         TRANSMITTER_ROLE: false,
//       },
//     },
//     integrations: {
//       "80001": {
//         FastSwitchboard: {
//           TRIP_ROLE: false, // roleHash(TRIP_ROLE)
//           UNTRIP_ROLE: false,
//           WATCHER_ROLE: false, // roleChainHash(WATCHER_ROLE, 80001)
//           TRIP_ROLE_SLUG: false, // roleChainHash(TRIP_ROLE, 80001)
//         },
//         OptimisticSwitchboard: {},
//         NativeSwitchboard: {},
//       },
//     },
//   },
// };
