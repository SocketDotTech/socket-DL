import { config as dotenvConfig } from "dotenv";
import {
  ChainSocketAddresses,
  DeploymentAddresses,
  getAllAddresses,
  isMainnet,
  isTestnet,
} from "../../src";
import { mode, overrides } from "../deploy/config/config";
import MultiSigWrapperArtifact from "../../out/MultiSigWrapper.sol/MultiSigWrapper.json";
import { Signer, ethers } from "ethers";
import { getSocketSigner } from "../deploy/utils/socket-signer";
import { MultiSigWrapper } from "../../typechain-types";

dotenvConfig();

/**
 * Usage
 *
 * --sendtx         Send claim tx along with ownership check.
 *                  Default is only check owner, nominee.
 *                  Eg. npx --sendtx ts-node scripts/admin/rotate-owner/claim.ts
 *
 * --chains         Run only for specified chains.
 *                  Default is all chains.
 *                  Eg. npx --chains=10,2999 ts-node scripts/admin/rotate-owner/claim.ts
 *
 * --testnets       Run for testnets.
 *                  Default is false.
 */

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

const wrapperABI = MultiSigWrapperArtifact.abi;

export const main = async () => {
  await Promise.all(
    filteredChainSlugs.map(async (chainSlug) => {
      let chainAddresses: ChainSocketAddresses = addresses[chainSlug];
      const wrapperAddress = chainAddresses.MultiSigWrapper;
      const safeAddress = chainAddresses.SocketSafeProxy;
      const signer = await getSocketSigner(
        parseInt(chainSlug),
        chainAddresses,
        false,
        true
      );
      await checkAndUpdate(
        wrapperAddress,
        safeAddress,
        signer,
        chainSlug,
        `${chainSlug} wrapper`
      );
    })
  );
};

const checkAndUpdate = async (
  wrapperAddress: string,
  newSafeAddress: string,
  signer: Signer,
  chainSlug: string,
  label: string
) => {
  if (!wrapperAddress || !newSafeAddress) {
    console.log(`❗ ${label}: Invalid wrapper or safe address`);
    return;
  }

  const signerAddress = (await signer.getAddress()).toLowerCase();
  const wrapper = new ethers.Contract(
    wrapperAddress,
    wrapperABI,
    signer
  ) as MultiSigWrapper;
  label = label.padEnd(45);

  console.log(
    ` - ${label}: Checking: signer: ${signerAddress}, wrapper: ${wrapperAddress}`
  );

  const owner = (await wrapper.owner()).toLowerCase();
  const safe = (await wrapper.safe()).toLowerCase();
  if (safe === newSafeAddress.toLowerCase()) {
    console.log(` ✔ ${label}: Safe already updated`);
    return;
  }

  if (owner !== signerAddress) {
    console.log(`❗ ${label}: Not owner`);
    return;
  }

  if (sendTx) {
    console.log(
      `✨ ${label}: Updating safe, current safe: ${safe}, new safe: ${newSafeAddress}`
    );
    const tx = await wrapper.updateSafe(newSafeAddress, {
      ...(await overrides(parseInt(chainSlug))),
    });

    const receipt = await tx.wait();
    console.log(`🚀 ${label}: Done: ${receipt.transactionHash}`);
  } else {
    console.log(
      `✨ ${label}: Needs updating, current safe: ${safe}, new safe: ${newSafeAddress}`
    );
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
