import { config as dotenvConfig } from "dotenv";
import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  IntegrationTypes,
  getAllAddresses,
  isMainnet,
  isTestnet,
} from "../../../src";
import { mode, overrides } from "../../deploy/config/config";
import OwnableArtifact from "../../../out/Ownable.sol/Ownable.json";
import { Signer, ethers } from "ethers";
import { Ownable } from "../../../typechain-types/contracts/utils/Ownable";
import { getSocketSigner } from "../../deploy/utils/socket-signer";

dotenvConfig();

/**
 * Usage
 *
 * --sendtx         Send claim tx along with ownership check.
 *                  Default is only check owner, nominee.
 *                  Eg. npx --sendtx ts-node scripts/admin/rotate-owner/2-claim-with-multisig.ts
 *
 * --chains         Run only for specified chains.
 *                  Default is all chains.
 *                  Eg. npx --chains=10,2999 ts-node scripts/admin/rotate-owner/2-claim-with-multisig.ts
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

const ownableABI = OwnableArtifact.abi;

export const main = async () => {
  await Promise.all(
    filteredChainSlugs.map(async (chainSlug) => {
      let chainAddresses: ChainSocketAddresses = addresses[chainSlug];
      const signerAddress = chainAddresses["SocketSafeProxy"];
      const signer = await getSocketSigner(
        parseInt(chainSlug),
        chainAddresses,
        true,
        true
      );

      // startBlock field ignored since it is not contract
      // integrations iterated later since it is an object
      const contractList = Object.keys(chainAddresses).filter(
        (key) =>
          ![
            "startBlock",
            "integrations",
            "Counter",
            "SafeL2",
            "SocketSafeProxy",
            "SafeProxyFactory",
            "MultiSigWrapper",
          ].includes(key)
      );
      for (const contractName of contractList) {
        const contractAddress = chainAddresses[contractName];
        const label = `${chainSlug}, ${contractName}`;
        await checkAndClaim(
          contractAddress,
          signer,
          chainSlug,
          label,
          signerAddress
        );
      }

      // iterate over integrations to check caps and decaps
      const siblingList = !!chainAddresses.integrations
        ? Object.keys(chainAddresses.integrations)
        : [];
      const integrationTypes = Object.values(IntegrationTypes);
      for (const sibling of siblingList) {
        for (const it of integrationTypes) {
          const capAddress =
            chainAddresses.integrations[sibling][it]?.capacitor;
          if (capAddress) {
            const label = `${chainSlug}-${it}-${sibling}, Cap`;
            await checkAndClaim(
              capAddress,
              signer,
              chainSlug,
              label,
              signerAddress
            );
          }

          const decapAddress =
            chainAddresses.integrations[sibling][it]?.decapacitor;
          if (decapAddress) {
            const label = `${chainSlug}-${it}-${sibling}, Decap`;
            await checkAndClaim(
              decapAddress,
              signer,
              chainSlug,
              label,
              signerAddress
            );
          }

          if (it === IntegrationTypes.native) {
            const sbAddress =
              chainAddresses.integrations[sibling][it]?.switchboard;
            if (sbAddress) {
              const label = `${chainSlug}-${it}-${sibling}, Switchboard`;
              await checkAndClaim(
                sbAddress,
                signer,
                chainSlug,
                label,
                signerAddress
              );
            }
          }
        }
      }
    })
  );
};

const checkAndClaim = async (
  contractAddress: string,
  signer: Signer,
  chainSlug: string,
  label: string,
  signerAddress: string
) => {
  label = label.padEnd(45);
  const contract = new ethers.Contract(
    contractAddress,
    ownableABI,
    signer
  ) as Ownable;

  const owner = (await contract.owner()).toLowerCase();
  const nominee = (await contract.nominee()).toLowerCase();
  signerAddress = signerAddress.toLowerCase();

  console.log(` - ${label}: Checking: ${owner}, ${nominee}`);

  if (signerAddress === owner) {
    console.log(` ✔ ${label}: Already claimed`);
    return;
  }

  if (signerAddress !== nominee) {
    console.log(`❗ ${label}: Signer is not current nominee`);
    return;
  }

  if (sendTx) {
    console.log(`✨ ${label}: Claiming`);
    const tx = await contract.claimOwner({
      ...(await overrides(parseInt(chainSlug))),
    });
    const receipt = await tx.wait();
    console.log(`🚀 ${label}: Done: ${receipt.transactionHash}`);
    await wait(1000);
  } else {
    console.log(`✨ ${label}: Needs claiming`);
  }
};

const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
