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
 * --watcher       Watcher address to revoke on all supported FAST paths.
 *                 This flag is required.
 *                 Eg. npx --watcher=0x5f34 ts-node scripts/admin/revoke-all-fast-switchboard-watcher.ts
 *
 * --sendtx        Submit revokeWatcherRole txs via Safe multisig.
 *                 Default is false and only prints required actions.
 *                 Eg. npx --watcher=0x5f34 --sendtx=true ts-node scripts/admin/revoke-all-fast-switchboard-watcher.ts
 */

type WatcherRevokeOp = {
  executionChainSlug: ChainSlug;
  sourceChainSlug: ChainSlug;
  destinationChainSlug: ChainSlug;
  switchboardAddress: string;
  pathLabel: string;
};

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
const addresses: DeploymentAddresses = getAllAddresses(mode);
const supportedChains = new Set(batcherSupportedChainSlugs);
const signerCache = new Map<ChainSlug, Awaited<ReturnType<typeof getSocketSigner>>>();
const CHAIN_PARALLELISM = 10;

const main = async () => {
  const operations = getWatcherRevokeOps(addresses);

  if (!operations.length) {
    console.log(
      `No FAST paths found in ${mode} mode where both chains are in batcherSupportedChainSlugs`
    );
    return;
  }

  console.log(
    `Found ${operations.length} FAST watcher revoke(s) where both chains are in batcherSupportedChainSlugs`
  );

  const operationsByChain = new Map<ChainSlug, WatcherRevokeOp[]>();
  for (const operation of operations) {
    if (!operationsByChain.has(operation.executionChainSlug)) {
      operationsByChain.set(operation.executionChainSlug, []);
    }
    operationsByChain.get(operation.executionChainSlug)!.push(operation);
  }

  const chainGroups = Array.from(operationsByChain.entries());
  for (let index = 0; index < chainGroups.length; index += CHAIN_PARALLELISM) {
    const chunk = chainGroups.slice(index, index + CHAIN_PARALLELISM);
    console.log(
      `\nProcessing chain chunk ${index / CHAIN_PARALLELISM + 1}: ${chunk
        .map(([executionChainSlug]) => executionChainSlug)
        .join(",")}`
    );

    await Promise.all(
      chunk.map(async ([executionChainSlug, chainOperations]) => {
        console.log(
          `\nProcessing execution chain ${executionChainSlug} with ${chainOperations.length} path(s)`
        );

        for (const operation of chainOperations) {
          await checkAndRevokeWatcher(operation);
        }
      })
    );
  }
};

const getWatcherRevokeOps = (
  allAddresses: DeploymentAddresses
): WatcherRevokeOp[] => {
  const ops = new Map<string, WatcherRevokeOp>();

  for (const [sourceChain, sourceAddresses] of Object.entries(allAddresses)) {
    const sourceChainSlug = Number(sourceChain) as ChainSlug;
    if (!supportedChains.has(sourceChainSlug)) continue;

    const outboundSiblings = Object.keys(sourceAddresses?.integrations ?? {});
    for (const sibling of outboundSiblings) {
      const destinationChainSlug = Number(sibling) as ChainSlug;
      if (!supportedChains.has(destinationChainSlug)) continue;

      const hasFastPath =
        !!sourceAddresses?.integrations?.[destinationChainSlug]?.[
          IntegrationTypes.fast
        ];
      if (!hasFastPath) continue;

      const switchboardAddress =
        allAddresses[destinationChainSlug]?.FastSwitchboard;
      if (!switchboardAddress) {
        console.log(
          `❗ ${sourceChainSlug} -> ${destinationChainSlug}: FastSwitchboard address not found`
        );
        continue;
      }

      const key = `${destinationChainSlug}-${sourceChainSlug}-${switchboardAddress.toLowerCase()}`;
      if (ops.has(key)) continue;

      ops.set(key, {
        executionChainSlug: destinationChainSlug,
        sourceChainSlug,
        destinationChainSlug,
        switchboardAddress,
        pathLabel: `${sourceChainSlug} -> ${destinationChainSlug}`,
      });
    }
  }

  return Array.from(ops.values()).sort((a, b) => {
    if (a.executionChainSlug !== b.executionChainSlug) {
      return a.executionChainSlug - b.executionChainSlug;
    }
    if (a.sourceChainSlug !== b.sourceChainSlug) {
      return a.sourceChainSlug - b.sourceChainSlug;
    }
    return a.destinationChainSlug - b.destinationChainSlug;
  });
};

const getCachedSigner = async (chainSlug: ChainSlug) => {
  const cachedSigner = signerCache.get(chainSlug);
  if (cachedSigner) return cachedSigner;

  const executionChainAddresses = addresses[chainSlug] as ChainSocketAddresses;
  const signer = await getSocketSigner(
    chainSlug,
    executionChainAddresses,
    true,
    false
  );

  signerCache.set(chainSlug, signer);
  return signer;
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

  const signer = await getCachedSigner(operation.executionChainSlug);
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
  const receipt = await tx.wait();
  console.log(`🚀 ${label}: Done: ${receipt.transactionHash}`);
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
