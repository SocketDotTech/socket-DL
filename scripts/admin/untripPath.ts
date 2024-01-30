import { Contract, Wallet, utils } from "ethers";
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

const addresses: DeploymentAddresses = getAllAddresses(mode);
const testnets = process.env.npm_config_testnets == "true";
let activeChainSlugs: string[];
if (testnets)
  activeChainSlugs = Object.keys(addresses).filter((c) =>
    isTestnet(parseInt(c))
  );
else
  activeChainSlugs = Object.keys(addresses).filter((c) =>
    isMainnet(parseInt(c))
  );
const sendTx = process.env.npm_config_sendtx == "true";
const integrationType = process.env.npm_config_integration
  ? process.env.npm_config_integration.toUpperCase()
  : IntegrationTypes.fast;
let filterChains = process.env.npm_config_chains
  ? process.env.npm_config_chains.split(",").map((c) => Number(c))
  : activeChainSlugs;

let siblingFilterChains = process.env.npm_config_sibling_chains
  ? process.env.npm_config_sibling_chains.split(",").map((c) => Number(c))
  : undefined;

const main = async () => {
  if (
    integrationType &&
    integrationType !== IntegrationTypes.fast &&
    integrationType !== IntegrationTypes.optimistic
  ) {
    throw new Error("Invalid integration type. Can be FAST or OPTIMISTIC");
  }
  filterChains = filterChains.map((c) => Number(c));
  console.log({ filterChains });
  for (const chain of filterChains) {
    console.log("======= Checking ", { chain }, "==============");

    let siblingChains = siblingFilterChains
      ? siblingFilterChains
      : getSiblings(deploymentMode, Number(chain) as ChainSlug);

    for (const siblingChain of siblingChains) {
      const switchboard = getSwitchboardInstance(
        chain,
        siblingChain,
        integrationType as IntegrationTypes,
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
        console.log({
          src: siblingChain,
          dst: chain,
          type: integrationType,
          tripStatus,
        });
      } catch (error) {
        console.log("RPC Error while fetching trip status: ", error);
        continue;
      }
      if (!tripStatus) continue;

      if (sendTx) {
        let hasRole = await checkRole(ROLES.UN_TRIP_ROLE, switchboard);
        if (!hasRole) break;
        console.log("untripping path...");

        const nonce = await switchboard.nextNonce(
          switchboard.signer.getAddress()
        );
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

        const signature = await switchboard.signer.signMessage(
          arrayify(digest)
        );

        const tx = await switchboard.unTripPath(
          nonce,
          siblingChain,
          signature,
          { ...overrides(chain) }
        );
        console.log(tx.hash);

        await tx.wait();
        console.log("done");
      }
    }
  }
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
