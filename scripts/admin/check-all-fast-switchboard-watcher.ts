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
import { mode } from "../deploy/config/config";
import { getSocketSigner } from "../deploy/utils/socket-signer";
import { getRoleHash } from "../deploy/utils";
import { FastSwitchboard__factory } from "../../typechain-types";
import { batcherSupportedChainSlugs } from "../rpcConfig/constants/batcherSupportedChainSlug";

dotenvConfig();

/**
 * Usage
 *
 * --watcher       Watcher address to check on all supported FAST paths.
 *                 This flag is required.
 *                 Eg. npx --watcher=0x5f34 ts-node scripts/admin/check-all-fast-switchboard-watcher.ts
 *
 * --chains        Optional comma-separated chain slugs. A path is checked if either
 *                 its source or destination chain matches one of these values.
 *                 Eg. npx --watcher=0x5f34 --chains=1,10,42161 ts-node scripts/admin/check-all-fast-switchboard-watcher.ts
 */

type WatcherCheckOp = {
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

const chainFilterParam = process.env.npm_config_chains;
const chainFilter = chainFilterParam
  ? new Set(
      chainFilterParam.split(",").map((chain) => {
        const chainSlug = Number(chain.trim());
        if (Number.isNaN(chainSlug)) {
          console.error(`Error: invalid chain slug "${chain}"`);
          process.exit(1);
        }
        return chainSlug as ChainSlug;
      })
    )
  : null;

const addresses: DeploymentAddresses = getAllAddresses(mode);
const supportedChains = new Set(batcherSupportedChainSlugs);
const signerCache = new Map<ChainSlug, Awaited<ReturnType<typeof getSocketSigner>>>();
const CHAIN_PARALLELISM = 10;

const main = async () => {
  const operations = getWatcherCheckOps(addresses, chainFilter);

  if (!operations.length) {
    console.log(
      `No FAST paths found in ${mode} mode where both chains are in batcherSupportedChainSlugs${
        chainFilter ? ` and either source or destination is in ${Array.from(chainFilter).join(",")}` : ""
      }`
    );
    return;
  }

  console.log(
    `Checking ${operations.length} FAST path(s) where both chains are in batcherSupportedChainSlugs${
      chainFilter ? ` and either source or destination is in ${Array.from(chainFilter).join(",")}` : ""
    }`
  );

  const operationsByChain = new Map<ChainSlug, WatcherCheckOp[]>();
  for (const operation of operations) {
    if (!operationsByChain.has(operation.executionChainSlug)) {
      operationsByChain.set(operation.executionChainSlug, []);
    }
    operationsByChain.get(operation.executionChainSlug)!.push(operation);
  }

  let matches = 0;
  const chainGroups = Array.from(operationsByChain.entries());
  for (let index = 0; index < chainGroups.length; index += CHAIN_PARALLELISM) {
    const chunk = chainGroups.slice(index, index + CHAIN_PARALLELISM);
    console.log(
      `\nProcessing chain chunk ${index / CHAIN_PARALLELISM + 1}: ${chunk
        .map(([executionChainSlug]) => executionChainSlug)
        .join(",")}`
    );

    const chunkMatches = await Promise.all(
      chunk.map(async ([executionChainSlug, chainOperations]) => {
        console.log(
          `\nChecking execution chain ${executionChainSlug} with ${chainOperations.length} path(s)`
        );

        let chainMatches = 0;
        for (const operation of chainOperations) {
          chainMatches += await checkWatcherRole(operation);
        }
        return chainMatches;
      })
    );

    matches += chunkMatches.reduce((sum, count) => sum + count, 0);
  }

  console.log(`\nFound watcher role on ${matches} path(s)`);
};

const getWatcherCheckOps = (
  allAddresses: DeploymentAddresses,
  chainFilterSet: Set<ChainSlug> | null
): WatcherCheckOp[] => {
  const ops = new Map<string, WatcherCheckOp>();

  for (const [sourceChain, sourceAddresses] of Object.entries(allAddresses)) {
    const sourceChainSlug = Number(sourceChain) as ChainSlug;
    if (!supportedChains.has(sourceChainSlug)) continue;

    const outboundSiblings = Object.keys(sourceAddresses?.integrations ?? {});
    for (const sibling of outboundSiblings) {
      const destinationChainSlug = Number(sibling) as ChainSlug;
      if (!supportedChains.has(destinationChainSlug)) continue;
      if (
        chainFilterSet &&
        !chainFilterSet.has(sourceChainSlug) &&
        !chainFilterSet.has(destinationChainSlug)
      ) {
        continue;
      }

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

const checkWatcherRole = async (operation: WatcherCheckOp): Promise<number> => {
  const executionChainAddresses =
    addresses[operation.executionChainSlug] as ChainSocketAddresses;

  if (
    !executionChainAddresses.SocketSafeProxy ||
    !executionChainAddresses.MultiSigWrapper
  ) {
    console.log(
      `❗ ${operation.pathLabel}: Safe config not found on chain ${operation.executionChainSlug}`
    );
    return 0;
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

  if (!hasRole) return 0;

  const label =
    `${operation.pathLabel} on ${operation.executionChainSlug}`.padEnd(32);
  console.log(
    `✔ ${label}: switchboard=${operation.switchboardAddress}, src=${operation.sourceChainSlug}, watcher=${watcherAddress}`
  );

  return 1;
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
