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
import { ethers } from "ethers";
import { Safe__factory } from "../../../typechain-types";

dotenvConfig();

/**
 * Usage
 *
 * --owner          Specify the owner to remove.
 *                  This flag is required.
 *                  Eg. npx --owner=0x5f34 ts-node scripts/admin/rotate-owner/6-remove-owner.ts
 *
 * --sendtx         Send remove owner tx along with ownership check.
 *                  Default is only check current owners and threshold.
 *                  Eg. npx --owner=0x5f34 --sendtx=true ts-node scripts/admin/rotate-owner/6-remove-owner.ts
 *
 * --chains         Run only for specified chains.
 *                  Default is all chains.
 *                  Eg. npx --owner=0x5f34 --chains=10,2999 ts-node scripts/admin/rotate-owner/6-remove-owner.ts
 *
 * --testnets       Run for testnets.
 *                  Default is false.
 */

let ownerToRemove = process.env.npm_config_owner;
if (!ownerToRemove) {
  console.error("Error: owner flag is required");
  process.exit(1);
}

if (!ethers.utils.isAddress(ownerToRemove)) {
  console.error("Error: owner is not a valid address");
  process.exit(1);
}

ownerToRemove = ownerToRemove.toLowerCase();

const SENTINEL_OWNERS = "0x0000000000000000000000000000000000000001";
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

      await checkAndRemoveOwner(safeAddress, safe, signer, chainSlug);
    })
  );
};

const checkAndRemoveOwner = async (
  safeAddress: string,
  safe: ReturnType<typeof Safe__factory.connect>,
  signer: Awaited<ReturnType<typeof getSocketSigner>>,
  chainSlug: string
) => {
  const label = `${chainSlug} safe`.padEnd(45);
  const owners = (await safe.getOwners()).map((owner) => owner.toLowerCase());
  const currentThreshold = await safe.getThreshold();

  console.log(
    ` - ${label}: Checking: threshold=${currentThreshold.toString()}, owners=${owners.join(",")}`
  );

  const ownerIndex = owners.indexOf(ownerToRemove!);
  if (ownerIndex === -1) {
    console.log(` ✔ ${label}: Owner already absent`);
    return;
  }

  if (currentThreshold.lte(1)) {
    console.log(
      `❗ ${label}: Cannot remove owner while reducing threshold by 1 from ${currentThreshold.toString()}`
    );
    return;
  }

  const prevOwner =
    ownerIndex === 0 ? SENTINEL_OWNERS : owners[ownerIndex - 1];
  const newThreshold = currentThreshold.sub(1);

  const transaction = {
    to: safeAddress,
    data: safe.interface.encodeFunctionData("removeOwner", [
      prevOwner,
      ownerToRemove,
      newThreshold,
    ]),
    ...(await overrides(await signer.getChainId())),
  };

  if (!sendTx) {
    console.log(
      `✨ ${label}: Needs removing owner ${ownerToRemove} with new threshold ${newThreshold.toString()}`
    );
    console.log(`   prevOwner=${prevOwner}`);
    return;
  }

  const isSubmitted = await signer.isTxHashSubmitted(transaction);
  if (isSubmitted) {
    console.log(` ✔ ${label}: Tx already submitted`);
    return;
  }

  console.log(
    `✨ ${label}: Removing owner ${ownerToRemove} with new threshold ${newThreshold.toString()}`
  );
  console.log(`   prevOwner=${prevOwner}`);
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
