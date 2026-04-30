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
 * --newowner       Specify the new owner to be added.
 *                  This flag is required.
 *                  Eg. npx --newowner=0x5f34 ts-node scripts/admin/rotate-owner/4-add-owner.ts
 *
 * --sendtx         Send add owner tx along with ownership check.
 *                  Default is only check current owners and threshold.
 *                  Eg. npx --newowner=0x5f34 --sendtx ts-node scripts/admin/rotate-owner/4-add-owner.ts
 *
 * --chains         Run only for specified chains.
 *                  Default is all chains.
 *                  Eg. npx --newowner=0x5f34 --chains=10,2999 ts-node scripts/admin/rotate-owner/4-add-owner.ts
 *
 * --testnets       Run for testnets.
 *                  Default is false.
 */

let newOwner = process.env.npm_config_newowner;
if (!newOwner) {
  console.error("Error: newowner flag is required");
  process.exit(1);
}

if (!ethers.utils.isAddress(newOwner)) {
  console.error("Error: newowner is not a valid address");
  process.exit(1);
}

newOwner = newOwner.toLowerCase();

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

      await checkAndAddOwner(safeAddress, safe, signer, chainSlug);
    })
  );
};

const checkAndAddOwner = async (
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

  if (owners.includes(newOwner!)) {
    console.log(` ✔ ${label}: Already an owner`);
    return;
  }

  const transaction = {
    to: safeAddress,
    data: safe.interface.encodeFunctionData("addOwnerWithThreshold", [
      newOwner,
      currentThreshold,
    ]),
    ...(await overrides(await signer.getChainId())),
  };

  if (!sendTx) {
    console.log(
      `✨ ${label}: Needs adding owner with preserved threshold ${currentThreshold.toString()}`
    );
    return;
  }

  const isSubmitted = await signer.isTxHashSubmitted(transaction);
  if (isSubmitted) {
    console.log(` ✔ ${label}: Tx already submitted`);
    return;
  }

  console.log(
    `✨ ${label}: Adding owner ${newOwner} with threshold ${currentThreshold.toString()}`
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
