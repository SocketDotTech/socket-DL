import { config as dotenvConfig } from "dotenv";
import {
  CORE_CONTRACTS,
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  ROLES,
  getAllAddresses,
  isMainnet,
  isTestnet,
} from "../../../src";
import {
  executionManagerVersion,
  mode,
  ownerAddresses,
} from "../../deploy/config/config";
import { Wallet, ethers } from "ethers";
import { checkAndUpdateRoles } from "../../deploy/scripts/roles";
import { sleep } from "@socket.tech/dl-common";

dotenvConfig();

/**
 * Usage
 *
 * --sendtx         Send nominate tx along with ownership check.
 *                  Default is only check owner, nominee.
 *                  Eg. npx --sendtx ts-node scripts/admin/rotate-owner/3-migrate-roles-to-multisig.ts
 *
 * --chains         Run only for specified chains.
 *                  Default is all chains.
 *                  Eg. npx --chains=10,2999 ts-node scripts/admin/rotate-owner/3-migrate-roles-to-multisig.ts
 *
 * --testnets       Run for testnets.
 *                  Default is false.
 */

const signerKey = process.env.SOCKET_SIGNER_KEY;
if (!signerKey) {
  console.error("Error: SOCKET_SIGNER_KEY is required");
}

const sendTransaction = process.env.npm_config_sendtx == "true";

const testnets = process.env.npm_config_testnets == "true";
const filterChainsParam = process.env.npm_config_chains
  ? process.env.npm_config_chains.split(",")
  : null;

const addresses: DeploymentAddresses = getAllAddresses(mode);
let allChainSlugs: string[];
if (testnets)
  allChainSlugs = Object.keys(addresses).filter((c) => isTestnet(parseInt(c)));
else
  allChainSlugs = Object.keys(addresses).filter((c) => isMainnet(parseInt(c)));

const filteredChainSlugs = !filterChainsParam
  ? allChainSlugs
  : allChainSlugs.filter((c) => filterChainsParam.includes(c));

const wallet: Wallet = new ethers.Wallet(signerKey);
const signerAddress = wallet.address.toLowerCase();
const signingOwnerAddress = ownerAddresses[mode].toLowerCase();

if (signingOwnerAddress != signerAddress) {
  console.error("Error: signingOwnerAddress is not the same as signerAddress");
  process.exit(1);
}

const sleepTime = 1;
const summary: { params: any; roleStatus: any }[] = [];

export const main = async () => {
  await Promise.all(
    filteredChainSlugs
      .map((c) => parseInt(c) as ChainSlug)
      .map(async (chainSlug) => {
        let chainAddresses: ChainSocketAddresses = addresses[chainSlug];

        const safeAddress = chainAddresses["SocketSafeProxy"];

        if (!safeAddress) {
          console.error(`Error: safeAddress not found for ${chainSlug}`);
          return;
        }

        const siblings = (
          !!chainAddresses.integrations
            ? Object.keys(chainAddresses.integrations)
            : []
        ).map((s) => parseInt(s) as ChainSlug);

        for (const contract of Object.keys(rolesToGrant)) {
          const roles = rolesToGrant[contract];
          const s = await checkAndUpdateRoles(
            {
              userSpecificRoles: [
                {
                  userAddress: safeAddress,
                  filterRoles: roles,
                },
              ],
              contractName: contract as CORE_CONTRACTS,
              filterChains: [chainSlug],
              filterSiblingChains: siblings,
              safeChains: [chainSlug],
              sendTransaction,
              newRoleStatus: true,
            },
            addresses
          );

          summary.push(s);
          await sleep(sleepTime);
        }

        for (const contract of Object.keys(rolesToRevoke)) {
          const roles = rolesToRevoke[contract];
          const s = await checkAndUpdateRoles(
            {
              userSpecificRoles: [
                {
                  userAddress: signingOwnerAddress,
                  filterRoles: roles,
                },
              ],
              contractName: contract as CORE_CONTRACTS,
              filterChains: [chainSlug],
              filterSiblingChains: siblings,
              safeChains: [chainSlug],
              sendTransaction,
              newRoleStatus: false,
            },
            addresses
          );

          summary.push(s);
          await sleep(sleepTime);
        }
      })
  );

  console.log(JSON.stringify(summary));
};

const rolesToGrant = {
  [executionManagerVersion]: [
    ROLES.RESCUE_ROLE,
    ROLES.GOVERNANCE_ROLE,
    ROLES.WITHDRAW_ROLE,
    ROLES.FEES_UPDATER_ROLE,
  ],
  [CORE_CONTRACTS.TransmitManager]: [
    ROLES.RESCUE_ROLE,
    ROLES.GOVERNANCE_ROLE,
    ROLES.WITHDRAW_ROLE,
    ROLES.FEES_UPDATER_ROLE,
  ],
  [CORE_CONTRACTS.Socket]: [ROLES.RESCUE_ROLE, ROLES.GOVERNANCE_ROLE],
  [CORE_CONTRACTS.FastSwitchboard]: [
    ROLES.RESCUE_ROLE,
    ROLES.GOVERNANCE_ROLE,
    ROLES.TRIP_ROLE,
    ROLES.UN_TRIP_ROLE,
    ROLES.WITHDRAW_ROLE,
    ROLES.FEES_UPDATER_ROLE,
  ],
  [CORE_CONTRACTS.OptimisticSwitchboard]: [
    ROLES.TRIP_ROLE,
    ROLES.UN_TRIP_ROLE,
    ROLES.RESCUE_ROLE,
    ROLES.GOVERNANCE_ROLE,
    ROLES.FEES_UPDATER_ROLE,
  ],
  [CORE_CONTRACTS.NativeSwitchboard]: [
    ROLES.TRIP_ROLE,
    ROLES.UN_TRIP_ROLE,
    ROLES.GOVERNANCE_ROLE,
    ROLES.WITHDRAW_ROLE,
    ROLES.RESCUE_ROLE,
    ROLES.FEES_UPDATER_ROLE,
  ],
};

const rolesToRevoke = {
  [executionManagerVersion]: [
    ROLES.RESCUE_ROLE,
    ROLES.GOVERNANCE_ROLE,
    ROLES.WITHDRAW_ROLE,
  ],
  [CORE_CONTRACTS.TransmitManager]: [
    ROLES.RESCUE_ROLE,
    ROLES.GOVERNANCE_ROLE,
    ROLES.WITHDRAW_ROLE,
  ],
  [CORE_CONTRACTS.Socket]: [ROLES.RESCUE_ROLE, ROLES.GOVERNANCE_ROLE],
  [CORE_CONTRACTS.FastSwitchboard]: [
    ROLES.RESCUE_ROLE,
    ROLES.GOVERNANCE_ROLE,
    ROLES.WITHDRAW_ROLE,
  ],
  [CORE_CONTRACTS.OptimisticSwitchboard]: [
    ROLES.RESCUE_ROLE,
    ROLES.GOVERNANCE_ROLE,
  ],
  [CORE_CONTRACTS.NativeSwitchboard]: [
    ROLES.GOVERNANCE_ROLE,
    ROLES.WITHDRAW_ROLE,
    ROLES.RESCUE_ROLE,
  ],
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
