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
 * --sendtx         Send the noop Safe tx.
 *                  Default is false, only print Safe state and tx details.
 *                  Eg. npx --sendtx ts-node scripts/admin/rotate-owner/test-safe-noop.ts
 *
 * --chains         Run only for specified chains.
 *                  Default is all chains in the selected network set.
 *                  Eg. npx --chains=421614 --sendtx=true ts-node scripts/admin/rotate-owner/test-safe-noop.ts
 *
 * --testnets       Run for testnets.
 *                  Default is false.
 */

const sendTx = process.env.npm_config_sendtx == "true";
const testnets = process.env.npm_config_testnets == "true";
const filterChainsParam = process.env.npm_config_chains
  ? process.env.npm_config_chains.split(",")
  : null;

export const main = async () => {
  const addresses: DeploymentAddresses = getAllAddresses(mode);
  let allChainSlugs: string[];
  if (testnets)
    allChainSlugs = Object.keys(addresses).filter((c) => isTestnet(parseInt(c)));
  else
    allChainSlugs = Object.keys(addresses).filter((c) => isMainnet(parseInt(c)));

  const filteredChainSlugs = !filterChainsParam
    ? allChainSlugs
    : allChainSlugs.filter((c) => filterChainsParam.includes(c));

  await Promise.all(
    filteredChainSlugs.map(async (chainSlug) => {
      const chainAddresses: ChainSocketAddresses | undefined =
        addresses[chainSlug];

      if (!chainAddresses) {
        console.error(`Error: no deployment addresses found for chain ${chainSlug}`);
        return;
      }

      const safeAddress = chainAddresses.SocketSafeProxy;
      if (!safeAddress) {
        console.error(`Error: SocketSafeProxy not found for chain ${chainSlug}`);
        return;
      }

      const signer = await getSocketSigner(
        parseInt(chainSlug) as ChainSlug,
        chainAddresses,
        true,
        false
      );
      const safe = Safe__factory.connect(safeAddress, signer.provider!);

      const owners = await safe.getOwners();
      const threshold = await safe.getThreshold();
      const signerAddress = await signer.getAddress();

      const transaction = {
        to: safeAddress,
        value: "0",
        data: "0x",
        ...(await overrides(parseInt(chainSlug))),
      };

      console.log(`Safe (${chainSlug}): ${safeAddress}`);
      console.log(`Signer (${chainSlug}): ${signerAddress}`);
      console.log(`Threshold (${chainSlug}): ${threshold.toString()}`);
      console.log(`Owners (${chainSlug}): ${owners.join(",")}`);
      console.log(
        `Tx (${chainSlug}): to=${transaction.to}, value=${transaction.value}, data=${transaction.data}`
      );

      if (!sendTx) {
        console.log(
          `✨ ${chainSlug}: Dry run only. Pass --sendtx=true to submit the noop Safe tx.`
        );
        return;
      }

      const isSubmitted = await signer.isTxHashSubmitted(transaction);
      if (isSubmitted) {
        console.log(`✔ ${chainSlug}: Tx already submitted`);
        return;
      }

      const tx = await signer.sendTransaction(transaction);
      console.log(`✨ ${chainSlug}: Submitted: ${tx.hash}`);
      const receipt = await tx.wait();
      console.log(`🚀 ${chainSlug}: Done: ${receipt.transactionHash}`);
    })
  );
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
