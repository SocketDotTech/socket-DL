import {
  IntegrationTypes,
  ChainSlug,
  DeploymentMode,
  isTestnet,
  isMainnet,
} from "../../src";
import { mode, overrides } from "../deploy/config";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { checkRole, getSiblings } from "../common";
import {
  getAllAddresses,
  DeploymentAddresses,
  ROLES,
} from "@socket.tech/dl-core";
import dotenv from "dotenv";
import {
  getSwitchboardInstance,
  TRIP_GLOBAL_SIG_IDENTIFIER,
  TRIP_NATIVE_SIG_IDENTIFIER,
} from "../common";
import {
  addresses,
  testnets,
  sendTx,
  integrationType,
  filterChains,
  siblingFilterChains,
  formatMsg,
  SummaryObj,
  printSummary,
} from "./tripCommon";
import { BigNumberish, Contract } from "ethers";
dotenv.config();
const deploymentMode = process.env.DEPLOYMENT_MODE as DeploymentMode;

/**
 * Usable flags
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
  if (
    integrationType &&
    !Object.values(IntegrationTypes).includes(
      integrationType as IntegrationTypes
    )
  ) {
    throw new Error(
      "Invalid integration type. Can be FAST, NATIVE_BRIDGE or OPTIMISTIC"
    );
  }
  console.log({ filterChains });

  let summary: SummaryObj[] = [];

  for (const chain of filterChains) {
    let siblingChains = getSiblings(deploymentMode, Number(chain) as ChainSlug);

    if (siblingChains.length)
      console.log("======= Checking ", { chain }, "==============");
    let siblingChain = siblingChains[0];

    const switchboard = getSwitchboardInstance(
      chain,
      siblingChain,
      integrationType as IntegrationTypes,
      mode
    );
    if (switchboard === undefined) {
      console.log("Switchboard address not found for ", chain, "continuing...");
      continue;
    }

    let tripStatus: boolean;
    try {
      tripStatus = await switchboard.isGlobalTipped();
      console.log({ type: integrationType, tripStatus });
    } catch (error) {
      console.log("RPC Error while fetching trip status: ", error);
      continue;
    }

    if (tripStatus) continue; // as global trip, check for a single siblingChain is enough

    let userAddress = await switchboard.signer.getAddress();
    let hasRole = await checkRole(ROLES.TRIP_ROLE, switchboard, userAddress);
    if (!hasRole) {
      console.log(
        `${userAddress} doesn't have ${ROLES.TRIP_ROLE} for contract ${switchboard.address}`
      );
      continue;
    }
    const nonce = await switchboard.nextNonce(switchboard.signer.getAddress());
    let signature = await getSignature(chain, nonce, switchboard);

    summary.push({ chain, tripStatus, signature, nonce, ...overrides(chain) });

    if (sendTx) {
      const tx = await switchboard.tripGlobal(nonce, signature, {
        ...overrides(chain),
      });
      console.log(tx.hash);

      await tx.wait();
      console.log("done");
    }
  }
  printSummary(summary);
};

const getSignature = async (
  chain: ChainSlug,
  nonce: number,
  switchboard: Contract
) => {
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
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });

// npx ts-node scripts/admin/tripGlobal.ts  - check trip status for all mainnet chains
// npx --chains=421614  ts-node scripts/admin/tripGlobal.ts
// npx --sendtx --chains=421614  ts-node scripts/admin/tripGlobal.ts
// npx --sendtx --chains=421614 --integration=fast ts-node scripts/admin/tripGlobal.ts
// npx --sendtx --chains=421614 --testnets --integration=fast ts-node scripts/admin/tripGlobal.ts
