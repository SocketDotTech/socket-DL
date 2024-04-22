import { Contract, Wallet, utils } from "ethers";
import { IntegrationTypes, ChainSlug } from "../../src";
import { mode, overrides } from "../deploy/config";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { UN_TRIP_PATH_SIG_IDENTIFIER, checkRole, getSiblings } from "../common";
import { ROLES } from "@socket.tech/dl-core";
import { getSwitchboardInstance } from "../common";
import {
  sendTx,
  integrationType,
  filterChains,
  siblingFilterChains,
  SummaryObj,
  printSummary,
  deploymentMode,
  formatMsg,
} from "./tripCommon";

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
 * --integration  Run for specified integration type. Can be fast or optimistic.
 *                  Default is fast.
 */

const main = async () => {
  if (
    integrationType &&
    integrationType !== IntegrationTypes.fast &&
    integrationType !== IntegrationTypes.optimistic
  ) {
    throw new Error("Invalid integration type. Can be FAST or OPTIMISTIC");
  }
  console.log(
    formatMsg("Config", {
      integrationType,
      filterChains,
      siblingFilterChains,
      sendTx,
    })
  );

  let summary: SummaryObj[] = [];

  for (const chain of filterChains) {
    let siblingChains = siblingFilterChains
      ? siblingFilterChains
      : getSiblings(deploymentMode, Number(chain) as ChainSlug);

    if (!siblingChains.length) {
      console.log("No siblings found for ", chain, " continuing...");
      continue;
    }
    console.log(" Checking chain: ", chain);
    for (const siblingChain of siblingChains) {
      const switchboard = getSwitchboardInstance(
        chain,
        siblingChain,
        integrationType,
        mode
      );
      if (switchboard === undefined) {
        console.log(
          "============== No switchboard found ==============",
          { src: siblingChain },
          { dst: chain },
          { type: integrationType }
        );
        continue;
      }

      let tripStatus: boolean;
      try {
        tripStatus = await switchboard.isPathTripped(siblingChain);
        console.log({ src: siblingChain, dst: chain, tripStatus });
      } catch (error) {
        console.log("RPC Error while fetching trip status: ", error);
        continue;
      }
      if (!tripStatus) continue;

      let userAddress = await switchboard.signer.getAddress();
      let role = ROLES.UN_TRIP_ROLE;

      let hasRole = await checkRole(role, switchboard, userAddress);
      if (!hasRole) {
        console.log(
          `${userAddress} doesn't have ${role} for contract ${switchboard.address}`
        );
        continue;
      }
      const nonce = await switchboard.nextNonce(userAddress);
      let signature = await getSignature(
        chain,
        siblingChain,
        nonce,
        switchboard
      );

      summary.push({
        chain,
        hasRole,
        siblingChain,
        currentTripStatus: tripStatus,
        newTripStatus: !tripStatus,
        signature,
        nonce,
        ...overrides(chain),
      });

      if (sendTx) {
        await sendTxn(chain, siblingChain, nonce, signature, switchboard);
      }
    }
  }
  printSummary(summary);
};

const sendTxn = async (
  chain: ChainSlug,
  siblingChain: ChainSlug,
  nonce: number,
  signature: string,
  switchboard: Contract
) => {
  let tx = await switchboard.unTripPath(nonce, siblingChain, signature, {
    ...overrides(chain),
  });
  console.log(tx.hash);

  await tx.wait();
  console.log("done");
};

const getSignature = async (
  chain: ChainSlug,
  siblingChain: ChainSlug,
  nonce: number,
  switchboard: Contract
) => {
  const digest = keccak256(
    defaultAbiCoder.encode(
      ["bytes32", "address", "uint32", "uint32", "uint256", "bool"],
      [
        UN_TRIP_PATH_SIG_IDENTIFIER,
        switchboard.address,
        siblingChain,
        chain,
        nonce,
        false,
      ]
    )
  );

  return await switchboard.signer.signMessage(arrayify(digest));
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

// npx ts-node scripts/admin/unTripPath.ts  - check trip status for all mainnet chains
// npx --chains=421614  ts-node scripts/admin/unTripPath.ts
// npx --sendtx --chains=421614  ts-node scripts/admin/unTripPath.ts
// npx --sendtx --chains=421614 --integration=fast ts-node scripts/admin/unTripPath.ts
// npx --sendtx --chains=421614 --testnets --integration=fast ts-node scripts/admin/unTripPath.ts
