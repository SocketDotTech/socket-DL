import { config as dotenvConfig } from "dotenv";
import { ethers } from "ethers";

import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  ROLES,
  getAllAddresses,
} from "../../src";
import {
  executorAddresses,
  mode,
  overrides,
} from "../deploy/config/config";
import { getSocketSigner } from "../deploy/utils/socket-signer";
import { getRoleHash } from "../deploy/utils";
import { ExecutionManagerDF__factory } from "../../typechain-types";

dotenvConfig();

/**
 * Usage
 *
 * --chains        Comma-separated chain slugs to process.
 *                 This flag is required.
 *                 Eg. npx --chains=1,10,42161 ts-node scripts/admin/grant-executor-role-emdf.ts
 *
 * --executor      Optional executor address override.
 *                 Default is executorAddresses[mode].
 *                 Eg. npx --chains=1,10 --executor=0x5f34 ts-node scripts/admin/grant-executor-role-emdf.ts
 *
 * --sendtx        Submit grantRole tx via Safe multisig.
 *                 Default is false and only prints required actions.
 *                 Eg. npx --chains=1,10 --sendtx=true ts-node scripts/admin/grant-executor-role-emdf.ts
 */

const chainsParam = process.env.npm_config_chains;
if (!chainsParam) {
  console.error("Error: chains flag is required");
  process.exit(1);
}

const chainSlugs = chainsParam.split(",").map((chain) => {
  const chainSlug = Number(chain.trim());
  if (Number.isNaN(chainSlug)) {
    console.error(`Error: invalid chain slug "${chain}"`);
    process.exit(1);
  }
  return chainSlug as ChainSlug;
});

let executorAddress = process.env.npm_config_executor || executorAddresses[mode];
if (!executorAddress) {
  console.error(`Error: executor address not configured for mode ${mode}`);
  process.exit(1);
}

if (!ethers.utils.isAddress(executorAddress)) {
  console.error("Error: executor is not a valid address");
  process.exit(1);
}

executorAddress = executorAddress.toLowerCase();

const sendTx = process.env.npm_config_sendtx === "true";
const addresses: DeploymentAddresses = getAllAddresses(mode);

const main = async () => {
  for (const chainSlug of chainSlugs) {
    await checkAndGrantExecutor(chainSlug);
  }
};

const checkAndGrantExecutor = async (chainSlug: ChainSlug) => {
  const chainAddresses = addresses[chainSlug] as ChainSocketAddresses | undefined;
  if (!chainAddresses) {
    console.log(`❗ ${chainSlug}: No deployment addresses found`);
    return;
  }

  const emdfAddress = chainAddresses.ExecutionManagerDF;
  if (!emdfAddress) {
    console.log(`❗ ${chainSlug}: ExecutionManagerDF address not found`);
    return;
  }

  if (!chainAddresses.SocketSafeProxy || !chainAddresses.MultiSigWrapper) {
    console.log(`❗ ${chainSlug}: Safe config not found`);
    return;
  }

  const signer = await getSocketSigner(chainSlug, chainAddresses, true, false);
  const emdf = ExecutionManagerDF__factory.connect(emdfAddress, signer);
  const roleHash = getRoleHash(ROLES.EXECUTOR_ROLE);

  const hasRole = await emdf.hasRole(roleHash, executorAddress!);
  const label = `${chainSlug} ExecutionManagerDF`.padEnd(32);

  console.log(
    ` - ${label}: contract=${emdfAddress}, executor=${executorAddress}`
  );

  if (hasRole) {
    console.log(` ✔ ${label}: Executor role already present`);
    return;
  }

  const populatedTx = await emdf.populateTransaction.grantRole(
    roleHash,
    executorAddress
  );

  const transaction = {
    to: emdf.address,
    data: populatedTx.data!,
    ...(await overrides(chainSlug)),
  };

  if (!sendTx) {
    console.log(`✨ ${label}: Needs executor role grant`);
    return;
  }

  const isSubmitted = await signer.isTxHashSubmitted(transaction);
  if (isSubmitted) {
    console.log(` ✔ ${label}: Tx already submitted`);
    return;
  }

  console.log(`✨ ${label}: Granting executor role via Safe`);
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
