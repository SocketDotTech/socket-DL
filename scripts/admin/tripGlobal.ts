import { IntegrationTypes, ChainSlug } from "../../src";
import { mode, overrides } from "../deploy/config/config";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import {
  UN_TRIP_GLOBAL_SIG_IDENTIFIER,
  UN_TRIP_NATIVE_SIG_IDENTIFIER,
  checkRole,
  getSiblings,
  getSwitchboardInstance,
  TRIP_GLOBAL_SIG_IDENTIFIER,
  TRIP_NATIVE_SIG_IDENTIFIER,
} from "../common";
import { ROLES } from "@socket.tech/dl-core";
import {
  sendTx,
  integrationType,
  filterChains,
  SummaryObj,
  printSummary,
  trip,
  untrip,
  deploymentMode,
  formatMsg,
} from "./tripCommon";
import { Contract } from "ethers";

/**
 * Usable flags
 * 
 * --trip         trip Global
 *                  Eg. npx --untrip ts-node scripts/admin/rescueFunds.ts
 * 
 * --untrip         unTrip Global
 *                  Eg. npx --untrip ts-node scripts/admin/rescueFunds.ts
 * 
 * --sendtx         Send trip tx 
 *                  Default is false, only check trip status.
 *                  Eg. npx --sendtx ts-node scripts/admin/rescueFunds.ts
 
 * --chains         Run only for specified chains.
 *                  Default is all chains.
 *                  Eg. npx --chains=10,2999 ts-node scripts/admin/tripGlobal.ts
 *
 * --testnets       Run for testnets.
 *                  Default is false.
 * 
 * --integration  Run for sepcified integration type. Can be fast or optimistic.
 *                  Default is fast.
 */

const main = async () => {
  if (trip && untrip) {
    console.log("both trip and untrip flags cant be passed. pass one of them.");
    return;
  }
  if (!trip && !untrip) {
    console.log("pass one of trip or untrip flag.");
    return;
  }

  if (
    integrationType &&
    !Object.values(IntegrationTypes).includes(integrationType)
  ) {
    throw new Error(
      "Invalid integration type. Can be FAST, NATIVE_BRIDGE or OPTIMISTIC"
    );
  }
  console.log(
    formatMsg("Config", { trip, untrip, integrationType, filterChains, sendTx })
  );

  let summary: SummaryObj[] = [];

  for (const chain of filterChains) {
    let siblingChains = getSiblings(deploymentMode, Number(chain) as ChainSlug);

    if (!siblingChains.length) {
      console.log("No siblings found for ", chain, " continuing...");
      continue;
    }
    console.log("\nChecking chain: ", chain);

    const switchboard = siblingChains
      .map((siblingChain) =>
        getSwitchboardInstance(chain, siblingChain, integrationType, mode)
      )
      .find((siblingChain) => !!siblingChain);

    if (switchboard === undefined) {
      console.log("Switchboard address not found for ", chain, "continuing...");
      continue;
    }

    let tripStatus: boolean;
    try {
      tripStatus = await switchboard.isGlobalTipped();
      console.log("trip status: ", tripStatus);
    } catch (error) {
      console.log("RPC Error while fetching trip status: ", error);
      continue;
    }

    if (trip && tripStatus) continue;
    if (untrip && !tripStatus) continue;

    let userAddress = await switchboard.signer.getAddress();
    let role: string;
    if (trip) role = ROLES.TRIP_ROLE;
    if (untrip) role = ROLES.UN_TRIP_ROLE;

    let hasRole = await checkRole(role, switchboard, userAddress);
    if (!hasRole) {
      console.log(
        `${userAddress} doesn't have ${role} for contract ${switchboard.address}`
      );
      continue;
    }
    const nonce = await switchboard.nextNonce(userAddress);
    let signature = await getSignature(chain, nonce, switchboard);

    summary.push({
      chain,
      hasRole,
      currentTripStatus: tripStatus,
      newTripStatus: !tripStatus,
      signature,
      nonce,
      ...overrides(chain),
    });

    if (sendTx) {
      await sendTxn(chain, nonce, signature, switchboard, trip, untrip);
    }
  }
  printSummary(summary);
};

const sendTxn = async (
  chain: ChainSlug,
  nonce: number,
  signature: string,
  switchboard: Contract,
  trip: boolean,
  untrip: boolean
) => {
  let tx;
  if (trip)
    tx = await switchboard.tripGlobal(nonce, signature, {
      ...overrides(chain),
    });
  if (untrip)
    tx = await switchboard.unTrip(nonce, signature, {
      ...overrides(chain),
    });
  console.log(tx.hash);

  await tx.wait();
  console.log("done");
};

const getSignature = async (
  chain: ChainSlug,
  nonce: number,
  switchboard: Contract
) => {
  if (trip) {
    let sigIdentifier =
      integrationType == IntegrationTypes.native
        ? TRIP_NATIVE_SIG_IDENTIFIER
        : TRIP_GLOBAL_SIG_IDENTIFIER;
    const digest = keccak256(
      defaultAbiCoder.encode(
        ["bytes32", "address", "uint32", "uint256", "bool"],
        [sigIdentifier, switchboard.address, chain, nonce, true]
      )
    );

    return await switchboard.signer.signMessage(arrayify(digest));
  }

  if (untrip) {
    let sigIdentifier =
      integrationType == IntegrationTypes.native
        ? UN_TRIP_NATIVE_SIG_IDENTIFIER
        : UN_TRIP_GLOBAL_SIG_IDENTIFIER;

    const digest = keccak256(
      defaultAbiCoder.encode(
        ["bytes32", "address", "uint32", "uint256", "bool"],
        [sigIdentifier, switchboard.address, chain, nonce, false]
      )
    );

    return await switchboard.signer.signMessage(arrayify(digest));
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

// TRIP Commands
// npx --trip ts-node scripts/admin/tripGlobal.ts  - check trip status for all mainnet chains
// npx --trip --chains=421614  ts-node scripts/admin/tripGlobal.ts
// npx --trip --sendtx --chains=421614  ts-node scripts/admin/tripGlobal.ts
// npx --trip --sendtx --chains=421614 --integration=fast ts-node scripts/admin/tripGlobal.ts
// npx --trip --sendtx --chains=421614 --testnets --integration=fast ts-node scripts/admin/tripGlobal.ts

// UNTRIP COMMANDS
// npx --untrip ts-node scripts/admin/tripGlobal.ts  - check trip status for all mainnet chains
// npx --untrip --chains=421614  ts-node scripts/admin/tripGlobal.ts
// npx --untrip --sendtx --chains=421614  ts-node scripts/admin/tripGlobal.ts
// npx --untrip --sendtx --chains=421614 --integration=fast ts-node scripts/admin/tripGlobal.ts
// npx --untrip --sendtx --chains=421614 --testnets --integration=fast ts-node scripts/admin/tripGlobal.ts
