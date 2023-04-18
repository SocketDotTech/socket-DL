import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import fs from "fs";
import {
  ChainSlug,
  TestnetIds,
  MainnetIds,
  ROLES,
  REQUIRED_ROLES,
  ChainSocketAddresses,
  REQUIRED_CHAIN_ROLES,
  IntegrationTypes,
} from "../../../src";
import {
  getInstance,
  getChainSlug,
  deployedAddressPath,
  getAddresses,
  getRoleHash,
  getChainRoleHash,
} from "../utils";
import { Contract, Wallet } from "ethers";
import { getABI } from "./getABIs";
import {
  chainSlugs,
  getProviderFromChainName,
  networkToChainSlug,
} from "../../constants";
import { Provider } from "@ethersproject/abstract-provider";
// import { executorAddress, attesterAddress } from "../config";


const testAddress = "0xb3ce44d09862a04dd27d5fc1eb33371db1c5918e";
let filterRoles = [ROLES.TRANSMITTER_ROLE];
let filterChains = [ChainSlug.MUMBAI];
let includeSwitchboard = false;
let sendTransaction = false;
let newRoleStatus = false; // true for GRANTING, false for REVOKING

let roleStatus: any = {};


let txns:{[chainId in ChainSlug]?:{to:string,data:string}[]} = {};

const addTransaction = (chainId:ChainSlug, contractAddress:string, instance:Contract, hasRole:boolean, role:string) => {
  console.log("reached here");
  if (!sendTransaction) return;
  if (hasRole===false && newRoleStatus===true) {
    console.log("granting")
    let data = instance.interface.encodeFunctionData("grantRole(bytes32,address)",[role, testAddress]);
    console.log(chainId, data);
    if (!txns[chainId]) txns[chainId] = [];
    txns[chainId]?.push({to:contractAddress, data});
    console.log(txns);
  }
  if (hasRole===true && newRoleStatus===false) {
    console.log("revoke")
    let data = instance.interface.encodeFunctionData("revokeRole(bytes32,address)",[role, testAddress]);
    if (!txns[chainId]) txns[chainId] = [];
    txns[chainId]?.push({to:contractAddress, data});
  } 
}

const executeTransactions = async () => {

  await Promise.all(
     Object.keys(txns).map(async (chainId:any) => {
      let provider = getProviderFromChainName(
        networkToChainSlug[chainId as any as ChainSlug] as keyof typeof chainSlugs
      );
      let wallet = new Wallet(process.env.LOAD_TEST_PRIVATE_KEY!, provider);

      let txnData;
      for (let i=0; i<txns[chainId as keyof typeof txns]!.length; i++) {
        try {
          txnData = txns[chainId as keyof typeof txns]![i];
          let tx = await wallet.sendTransaction({to:txnData?.to, data:txnData?.data});
          console.log(`chain: ${chainId}`, txnData?.to, tx.hash);
          await tx.wait();
        } catch (error) {
          console.log(chainId, txnData, error);
        }
      }
  }));
}

const checkSwitchBoardRoles = async (contractName:string, contractAddress:string, chainId:number, integrationChainId:number, provider:Provider) => {
  let instance = new Contract(
    contractAddress,
    getABI[contractName as keyof typeof getABI],
    provider
  );
  let requiredRoles =
    REQUIRED_ROLES[contractName as keyof typeof REQUIRED_ROLES];
  let requiredChainRoles = REQUIRED_CHAIN_ROLES[contractName as keyof typeof REQUIRED_CHAIN_ROLES];

  roleStatus[chainId]["integrations"][integrationChainId][contractName] = {};

  console.log(`checking ${chainId} integration ${integrationChainId} ${contractName}`);
  await Promise.all(requiredRoles.map( async (role) => {
    if (filterRoles.length>0 && !filterRoles.includes(role)) return;
    let hasRole = await instance.callStatic["hasRole(bytes32,address)"](
      getRoleHash(role),
      testAddress
    );
    roleStatus[chainId]["integrations"][integrationChainId][contractName][role] = hasRole;
    addTransaction(chainId, contractAddress, instance, hasRole, getRoleHash(role));
  }));

  console.log(`checking ${chainId} integration ${integrationChainId} ${contractName} chain specific`);

  if (requiredChainRoles?.length)
  await Promise.all(requiredChainRoles.map(async (role) => {
    if (filterRoles.length>0 && !filterRoles.includes(role)) return;
    let hasRole = await instance.callStatic["hasRole(bytes32,address)"](
      getChainRoleHash(role, Number(integrationChainId)),
      testAddress
    );
    roleStatus[chainId]["integrations"][integrationChainId][contractName][role+"_WITH_SLUG"] = hasRole;
    addTransaction(chainId, contractAddress, instance, hasRole, getChainRoleHash(role, Number(integrationChainId)));
  }))
}

export const main = async () => {
  try {
    
    await Promise.all( [...MainnetIds, ...TestnetIds].map(async (chainId) => {
      if (filterChains.length>0 && !filterChains.includes(chainId)) return;
      roleStatus[chainId] = {};
      roleStatus[chainId]["integrations"] = {};

      console.log("checking for network: ", networkToChainSlug[chainId], "=================");
      let addresses = await getAddresses(chainId);

      let integrations = addresses?.integrations;
      let integrationChainIds = integrations ? Object.keys(integrations) : [];
      // console.log(addresses);
      let provider = getProviderFromChainName(
        networkToChainSlug[chainId] as keyof typeof chainSlugs
      );
      console.log("checking integration switchboard roles...............")

      if (includeSwitchboard)
      await Promise.all(integrationChainIds.map(async (integrationChainId) => {
        roleStatus[chainId]["integrations"][integrationChainId] = {};
        let nativeSwitchboard =
          integrations![Number(integrationChainId) as ChainSlug]?.[IntegrationTypes.native]?.switchboard;
        let fastSwitchboard =
          integrations![Number(integrationChainId) as ChainSlug]?.[IntegrationTypes.fast]?.switchboard;
        let optimisticSwitchboard =
          integrations![Number(integrationChainId) as ChainSlug]?.[IntegrationTypes.optimistic]?.switchboard;

        let contractName;
        if (fastSwitchboard) {
          contractName = "FastSwitchboard";
          await checkSwitchBoardRoles(contractName, fastSwitchboard, chainId, Number(integrationChainId), provider);
        } else console.log("fast switchboard not found for integration chain Id: ", integrationChainId);
        if (optimisticSwitchboard) {
          contractName = "OptimisticSwitchboard";
          await checkSwitchBoardRoles(contractName, optimisticSwitchboard, chainId, Number(integrationChainId), provider);
        } else console.log("optimistic switchboard not found for integration chain Id: ", integrationChainId);
        if (nativeSwitchboard) {
          contractName = "NativeSwitchboard";
          await checkSwitchBoardRoles(contractName, nativeSwitchboard, chainId, Number(integrationChainId), provider);
        } else console.log(`${chainId} native switchboard not found for integration chain Id: `, integrationChainId);
      }))

      await Promise.all(Object.keys(REQUIRED_ROLES).map(async (contractName) => {
        if (contractName.includes("Switchboard")) return;

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
        let requiredChainRoles = REQUIRED_CHAIN_ROLES[contractName as keyof typeof REQUIRED_CHAIN_ROLES];

        await Promise.all( requiredRoles.map(async (role) => {
          if (filterRoles.length>0 && !filterRoles.includes(role)) return;
          let hasRole = await instance.callStatic["hasRole(bytes32,address)"](
            getRoleHash(role),
            testAddress
          );
          roleStatus[chainId][contractName][role] = hasRole;
          console.log(chainId, contractName, role, hasRole);
          addTransaction(chainId, contractAddress, instance, hasRole, getRoleHash(role));
        }));
        

        if (requiredChainRoles?.length)
        for (let n=0; n<integrationChainIds.length; n++) {
          
          let integrationChainId = integrationChainIds[n];
          roleStatus[chainId][contractName][integrationChainId] = {};

          await Promise.all(requiredChainRoles.map(async (role) => {
            if (filterRoles.length>0 && !filterRoles.includes(role)) return;
            let hasRole = await instance.callStatic["hasRole(bytes32,address)"](
              getChainRoleHash(role, Number(integrationChainId)),
              testAddress
            );
            roleStatus[chainId][contractName][integrationChainId][role] = hasRole;
            console.log(chainId, contractName, role, hasRole);
            addTransaction(chainId, contractAddress, instance, hasRole, getChainRoleHash(role, Number(integrationChainId)));
          
          }));
        }
      }))
    }));

    console.log(roleStatus, JSON.stringify(roleStatus));
    console.log(sendTransaction, txns);

    await executeTransactions();
    
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });


let result = {
  "5":{
    "TransmitManager":{
      "EXECUTOR_ROLE":false,
      "80001":{
        "TRANSMITTER_ROLE":false
      }
    },
    "integrations":{
      "80001":{
        "FastSwitchboard":{
          "TRIP_ROLE":false, // roleHash(TRIP_ROLE)
          "UNTRIP_ROLE":false,
          "WATCHER_ROLE":false, // roleChainHash(WATCHER_ROLE, 80001)
          "TRIP_ROLE_SLUG":false, // roleChainHash(TRIP_ROLE, 80001)

        },
        "OptimisticSwitchboard":{

        },
        "NativeSwitchboard":{

        }
      }
    }
  }
}