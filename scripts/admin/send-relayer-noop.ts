import { config as dotenvConfig } from "dotenv";

import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  getAllAddresses,
} from "../../src";
import { mode, overrides } from "../deploy/config/config";
import { getSocketSigner } from "../deploy/utils/socket-signer";

dotenvConfig();

/**
 * Usage
 *
 * --chains        Comma-separated chain slugs to process.
 *                 This flag is required.
 *                 Eg. npx --chains=1,10,42161 ts-node scripts/admin/send-relayer-noop.ts
 *
 * --sendtx        Submit the noop tx via relayer only.
 *                 Default is false and only prints tx details.
 *                 Eg. npx --chains=1,10,42161 --sendtx=true ts-node scripts/admin/send-relayer-noop.ts
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

const sendTx = process.env.npm_config_sendtx === "true";
const addresses: DeploymentAddresses = getAllAddresses(mode);

const main = async () => {
  for (const chainSlug of chainSlugs) {
    await checkAndSendNoop(chainSlug);
  }
};

const checkAndSendNoop = async (chainSlug: ChainSlug) => {
  const chainAddresses = addresses[chainSlug] as ChainSocketAddresses | undefined;
  if (!chainAddresses) {
    console.log(`❗ ${chainSlug}: No deployment addresses found`);
    return;
  }

  const signer = await getSocketSigner(chainSlug, chainAddresses, false, false);
  const signerAddress = await signer.getAddress();
  const label = `${chainSlug} relayer noop`.padEnd(32);

  const transaction = {
    to: signerAddress,
    value: "0",
    data: "0x",
    ...(await overrides(chainSlug)),
  };

  console.log(
    ` - ${label}: signer=${signerAddress}, tx=to:${transaction.to}, value:${transaction.value}, data:${transaction.data}`
  );

  console.log(transaction);
  if (!sendTx) {
    console.log(`✨ ${label}: Dry run only. Pass --sendtx=true to submit.`);
    return;
  }

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
