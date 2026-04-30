import { config as dotenvConfig } from "dotenv";
import { ethers } from "ethers";

import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  IntegrationTypes,
  ROLES,
  getAllAddresses,
} from "../../src";
import { mode, overrides } from "../deploy/config/config";
import { getSocketSigner } from "../deploy/utils/socket-signer";
import { getRoleHash } from "../deploy/utils";
import { FastSwitchboard__factory } from "../../typechain-types";
import { batcherSupportedChainSlugs } from "../rpcConfig/constants/batcherSupportedChainSlug";

dotenvConfig();

/**
 * Usage
 *
 * --chain         Chain slug whose FAST paths should have the watcher removed.
 *                 This flag is required.
 *                 Eg. npx --chain=42161 ts-node scripts/admin/revoke-fast-switchboard-watcher.ts
 *
 * --watcher       Watcher address to revoke on all matching FAST paths.
 *                 This flag is required.
 *                 Eg. npx --chain=42161 --watcher=0x5f34 ts-node scripts/admin/revoke-fast-switchboard-watcher.ts
 *
 * --siblings      Optional comma-separated sibling chain slugs to restrict the paths.
 *                 Eg. npx --chain=957 --siblings=1,10 --watcher=0x5f34 ts-node scripts/admin/revoke-fast-switchboard-watcher.ts
 *
 * --sendtx        Submit revokeWatcherRole txs via Safe multisig.
 *                 Default is false and only prints required actions.
 *                 Eg. npx --chain=42161 --watcher=0x5f34 --sendtx=true ts-node scripts/admin/revoke-fast-switchboard-watcher.ts
 */

type WatcherRevokeOp = {
  executionChainSlug: ChainSlug;
  sourceChainSlug: ChainSlug;
  switchboardAddress: string;
  pathLabel: string;
};

const chainParam = process.env.npm_config_chain;
if (!chainParam) {
  console.error("Error: chain flag is required");
  process.exit(1);
}

const targetChainSlug = Number(chainParam) as ChainSlug;
if (Number.isNaN(targetChainSlug)) {
  console.error("Error: chain must be a valid numeric chain slug");
  process.exit(1);
}

let watcherAddress = process.env.npm_config_watcher;
if (!watcherAddress) {
  console.error("Error: watcher flag is required");
  process.exit(1);
}

if (!ethers.utils.isAddress(watcherAddress)) {
  console.error("Error: watcher is not a valid address");
  process.exit(1);
}

watcherAddress = watcherAddress.toLowerCase();

const sendTx = process.env.npm_config_sendtx === "true";
const supportedChains = new Set(batcherSupportedChainSlugs);
const siblingFilterParam = process.env.npm_config_siblings;
const siblingFilter = siblingFilterParam
  ? new Set(
      siblingFilterParam.split(",").map((sibling) => {
        const siblingSlug = Number(sibling.trim());
        if (Number.isNaN(siblingSlug)) {
          console.error(`Error: invalid sibling chain slug "${sibling}"`);
          process.exit(1);
        }
        return siblingSlug as ChainSlug;
      })
    )
  : null;
const addresses: DeploymentAddresses = getAllAddresses(mode);

if (!addresses[targetChainSlug]) {
  console.error(
    `Error: no deployment addresses found for chain ${targetChainSlug}`
  );
  process.exit(1);
}

const main = async () => {
  const operations = getWatcherRevokeOps(
    addresses,
    targetChainSlug,
    siblingFilter
  );

  if (!operations.length) {
    console.log(
      `No FAST paths found where chain ${targetChainSlug} is involved in ${mode} mode and both chains are in batcherSupportedChainSlugs${
        siblingFilter ? ` for siblings ${Array.from(siblingFilter).join(",")}` : ""
      }`
    );
    return;
  }

  console.log(
    `Found ${operations.length} FAST watcher revoke(s) for chain ${targetChainSlug} where both chains are in batcherSupportedChainSlugs${
      siblingFilter ? ` filtered to siblings ${Array.from(siblingFilter).join(",")}` : ""
    }`
  );

  for (const operation of operations) {
    await checkAndRevokeWatcher(operation);
  }
};

const getWatcherRevokeOps = (
  allAddresses: DeploymentAddresses,
  chainSlug: ChainSlug,
  siblingFilterSet: Set<ChainSlug> | null
): WatcherRevokeOp[] => {
  const ops = new Map<string, WatcherRevokeOp>();
  const targetChainAddresses = allAddresses[chainSlug];

  if (!supportedChains.has(chainSlug)) return [];

  const addOp = (
    executionChainSlug: ChainSlug,
    sourceChainSlug: ChainSlug,
    switchboardAddress: string | undefined,
    pathLabel: string
  ) => {
    if (!switchboardAddress) {
      console.log(`❗ ${pathLabel}: FastSwitchboard address not found`);
      return;
    }

    const key = `${executionChainSlug}-${sourceChainSlug}-${switchboardAddress.toLowerCase()}`;
    if (ops.has(key)) return;

    ops.set(key, {
      executionChainSlug,
      sourceChainSlug,
      switchboardAddress,
      pathLabel,
    });
  };

  const outboundSiblings = Object.keys(targetChainAddresses?.integrations ?? {});
  for (const sibling of outboundSiblings) {
    const siblingSlug = Number(sibling) as ChainSlug;
    if (!supportedChains.has(siblingSlug)) continue;
    if (siblingFilterSet && !siblingFilterSet.has(siblingSlug)) continue;

    const hasFastPath =
      !!targetChainAddresses?.integrations?.[siblingSlug]?.[IntegrationTypes.fast];

    if (!hasFastPath) continue;

    addOp(
      siblingSlug,
      chainSlug,
      allAddresses[siblingSlug]?.FastSwitchboard,
      `${chainSlug} -> ${siblingSlug}`
    );
  }

  for (const [sourceChain, sourceAddresses] of Object.entries(allAddresses)) {
    const sourceChainSlug = Number(sourceChain) as ChainSlug;
    if (sourceChainSlug === chainSlug) continue;
    if (!supportedChains.has(sourceChainSlug)) continue;
    if (siblingFilterSet && !siblingFilterSet.has(sourceChainSlug)) continue;

    const hasFastPath =
      !!sourceAddresses?.integrations?.[chainSlug]?.[IntegrationTypes.fast];

    if (!hasFastPath) continue;

    addOp(
      chainSlug,
      sourceChainSlug,
      targetChainAddresses?.FastSwitchboard,
      `${sourceChainSlug} -> ${chainSlug}`
    );
  }

  return Array.from(ops.values()).sort((a, b) => {
    if (a.executionChainSlug !== b.executionChainSlug) {
      return a.executionChainSlug - b.executionChainSlug;
    }
    return a.sourceChainSlug - b.sourceChainSlug;
  });
};

const checkAndRevokeWatcher = async (operation: WatcherRevokeOp) => {
  const executionChainAddresses =
    addresses[operation.executionChainSlug] as ChainSocketAddresses;

  if (
    !executionChainAddresses.SocketSafeProxy ||
    !executionChainAddresses.MultiSigWrapper
  ) {
    console.log(
      `❗ ${operation.pathLabel}: Safe config not found on chain ${operation.executionChainSlug}`
    );
    return;
  }

  const signer = await getSocketSigner(
    operation.executionChainSlug,
    executionChainAddresses,
    true,
    false
  );

  const switchboard = FastSwitchboard__factory.connect(
    operation.switchboardAddress,
    signer
  );

  const hasRole = await switchboard.hasRoleWithSlug(
    getRoleHash(ROLES.WATCHER_ROLE),
    operation.sourceChainSlug,
    watcherAddress!
  );

  const label =
    `${operation.pathLabel} on ${operation.executionChainSlug}`.padEnd(32);

  console.log(
    ` - ${label}: switchboard=${operation.switchboardAddress}, src=${operation.sourceChainSlug}, watcher=${watcherAddress}`
  );

  if (!hasRole) {
    console.log(` ✔ ${label}: Watcher already absent`);
    return;
  }

  const populatedTx = await switchboard.populateTransaction.revokeWatcherRole(
    operation.sourceChainSlug,
    watcherAddress
  );

  const transaction = {
    to: switchboard.address,
    data: populatedTx.data!,
    ...(await overrides(operation.executionChainSlug)),
  };

  if (!sendTx) {
    console.log(`✨ ${label}: Needs watcher revoke`);
    return;
  }

  const isSubmitted = await signer.isTxHashSubmitted(transaction);
  if (isSubmitted) {
    console.log(` ✔ ${label}: Tx already submitted`);
    return;
  }

  console.log(`✨ ${label}: Revoking watcher via Safe`);
  const tx = await signer.sendTransaction(transaction);
  console.log(
    `📨 ${label}: Submitted via relayer${(tx as any).txId ? `, txId=${(tx as any).txId}` : ""}`
  );
  const receipt = await tx.wait();
  console.log(`🚀 ${label}: Done: ${receipt.transactionHash}`);
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
