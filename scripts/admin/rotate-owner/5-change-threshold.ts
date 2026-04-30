import { config as dotenvConfig } from "dotenv";
import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  getAllAddresses,
  isMainnet,
  isTestnet,
} from "../../../src";
import { mode, overrides } from "../../deploy/config/config";
import { getSocketSigner } from "../../deploy/utils/socket-signer";
import { Safe__factory } from "../../../typechain-types";

dotenvConfig();

/**
 * Usage
 *
 * --threshold      Specify the new threshold.
 *                  This flag is required.
 *                  Eg. npx --threshold=2 ts-node scripts/admin/rotate-owner/5-change-threshold.ts
 *
 * --sendtx         Send change threshold tx along with threshold check.
 *                  Default is only check current threshold.
 *                  Eg. npx --threshold=2 --sendtx ts-node scripts/admin/rotate-owner/5-change-threshold.ts
 *
 * --chains         Run only for specified chains.
 *                  Default is all chains.
 *                  Eg. npx --threshold=2 --chains=10,2999 ts-node scripts/admin/rotate-owner/5-change-threshold.ts
 *
 * --testnets       Run for testnets.
 *                  Default is false.
 */

const thresholdParam = process.env.npm_config_threshold;
if (!thresholdParam) {
  console.error("Error: threshold flag is required");
  process.exit(1);
}

const newThreshold = Number(thresholdParam);
if (!Number.isInteger(newThreshold) || newThreshold <= 0) {
  console.error("Error: threshold must be a positive integer");
  process.exit(1);
}

const sendTx = process.env.npm_config_sendtx == "true";
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

export const main = async () => {
  await Promise.all(
    filteredChainSlugs.map(async (chainSlug) => {
      const chainAddresses: ChainSocketAddresses = addresses[chainSlug];
      const safeAddress = chainAddresses.SocketSafeProxy;

      if (!safeAddress) {
        console.log(`❗ ${chainSlug}: SocketSafeProxy address not found`);
        return;
      }

      const signer = await getSocketSigner(
        parseInt(chainSlug) as ChainSlug,
        chainAddresses,
        true,
        false
      );
      const safe = Safe__factory.connect(safeAddress, signer.provider!);

      await checkAndChangeThreshold(safeAddress, safe, signer, chainSlug);
    })
  );
};

const checkAndChangeThreshold = async (
  safeAddress: string,
  safe: ReturnType<typeof Safe__factory.connect>,
  signer: Awaited<ReturnType<typeof getSocketSigner>>,
  chainSlug: string
) => {
  const label = `${chainSlug} safe`.padEnd(45);
  const owners = await safe.getOwners();
  const currentThreshold = await safe.getThreshold();

  console.log(
    ` - ${label}: Checking: threshold=${currentThreshold.toString()}, ownerCount=${owners.length}`
  );

  if (currentThreshold.eq(newThreshold)) {
    console.log(` ✔ ${label}: Threshold already updated`);
    return;
  }

  if (newThreshold > owners.length) {
    console.log(
      `❗ ${label}: Invalid threshold ${newThreshold}. Owner count is ${owners.length}`
    );
    return;
  }

  const transaction = {
    to: safeAddress,
    data: safe.interface.encodeFunctionData("changeThreshold", [newThreshold]),
    ...(await overrides(await signer.getChainId())),
  };

  if (!sendTx) {
    console.log(`✨ ${label}: Needs threshold update to ${newThreshold}`);
    return;
  }

  const isSubmitted = await signer.isTxHashSubmitted(transaction);
  if (isSubmitted) {
    console.log(` ✔ ${label}: Tx already submitted`);
    return;
  }

  console.log(
    `✨ ${label}: Updating threshold from ${currentThreshold.toString()} to ${newThreshold}`
  );
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
