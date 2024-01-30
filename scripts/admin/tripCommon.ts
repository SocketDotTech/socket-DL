import { BigNumberish, Contract, Wallet, utils } from "ethers";
import {
  IntegrationTypes,
  ChainSlug,
  DeploymentMode,
  isTestnet,
  isMainnet,
} from "../../src";
import { mode, overrides } from "../deploy/config";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { UN_TRIP_PATH_SIG_IDENTIFIER, checkRole, getSiblings } from "../common";
import {
  getAllAddresses,
  DeploymentAddresses,
  ROLES,
} from "@socket.tech/dl-core";
import dotenv from "dotenv";
import { getSwitchboardInstance } from "../common";

dotenv.config();
const deploymentMode = process.env.DEPLOYMENT_MODE as DeploymentMode;

export type SummaryObj = {
    chain: ChainSlug;
    nonce: number;
    tripStatus: boolean;
    signature: string;
    gasLimit?: BigNumberish;
    gasPrice?: BigNumberish;
    type?: number;
  };

/**
 * Usable flags
 * --sendtx         Send trip tx 
 *                  Default is false, only check trip status.
 *                  Eg. npx --sendtx ts-node scripts/admin/rescueFunds.ts
 
 * --chains         Run only for specified chains.
 *                  Default is all chains.
 *                  Eg. npx --chains=10,2999 ts-node scripts/admin/tripGlobal.ts
 *
 * --sibling_chains Run only for specified sibling chains.
 *                  Default is all sibling chains.
 *                  Eg. npx --sibling_chains=10,2999 ts-node scripts/admin/tripGlobal.ts
 *
 * --testnets       Run for testnets.
 *                  Default is false.
 * 
 * --integration  Run for sepcified integration type. Can be fast or optimistic.
 *                  Default is fast.
 */

export const addresses: DeploymentAddresses = getAllAddresses(mode);
export const testnets = process.env.npm_config_testnets == "true";
export let activeChainSlugs: string[];
if (testnets)
  activeChainSlugs = Object.keys(addresses).filter((c) =>
    isTestnet(parseInt(c))
  );
else
  activeChainSlugs = Object.keys(addresses).filter((c) =>
    isMainnet(parseInt(c))
  );
export const sendTx = process.env.npm_config_sendtx == "true";
export const integrationType = process.env.npm_config_integration
  ? process.env.npm_config_integration.toUpperCase()
  : IntegrationTypes.fast;
export let filterChains = process.env.npm_config_chains
  ? process.env.npm_config_chains.split(",").map((c) => Number(c))
  : activeChainSlugs.map((c) => Number(c));

export let siblingFilterChains = process.env.npm_config_sibling_chains
  ? process.env.npm_config_sibling_chains.split(",").map((c) => Number(c))
  : undefined;



export const printSummary = (summary:SummaryObj[]) => {
    console.log("\n========SUMMARY ==========\n")
  for (let summaryObj of summary) {
    let { chain, ...rest } = summaryObj;
    console.log(formatMsg(String(chain), rest));
  }
}
  
export const formatMsg = (title: string, data: any) => {
  let message = `=== ${title} ===\n`;

  // Iterate through the object's key-value pairs
  for (const key in data) {
    if (data.hasOwnProperty(key)) {
      message += `${key}: ${data[key]}\n`;
    }
  }
  return message;
};
