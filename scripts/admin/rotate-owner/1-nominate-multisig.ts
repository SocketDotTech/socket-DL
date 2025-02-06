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
import { getProviderFromChainSlug } from "../../constants";
import { Signer, Wallet, ethers } from "ethers";
import { Ownable } from "../../../typechain-types/contracts/utils/Ownable";

dotenvConfig();

/**
 * Usage
 *
 * --newowner       Specify the new owner to be nominated.
 *                  This flag is required.
 *                  Eg. npx --newowner=0x5f34 ts-node scripts/admin/rotate-owner/1-nominate.ts
 *
 * --sendtx         Send nominate tx along with ownership check.
 *                  Default is only check owner, nominee.
 *                  Eg. npx --newowner=0x5f34 --sendtx ts-node scripts/admin/rotate-owner/1-nominate.ts
 *
 * --chains         Run only for specified chains.
 *                  Default is all chains.
 *                  Eg. npx --newowner=0x5f34 --chains=10,2999 ts-node scripts/admin/rotate-owner/1-nominate.ts
 *
 * --testnets       Run for testnets.
 *                  Default is false.
 */

// let newOwner = process.env.npm_config_newowner;
// if (!newOwner) {
//   console.error("Error: newowner flag is required");
//   process.exit(1);
// }
// newOwner = newOwner.toLowerCase();

const signerKey = process.env.SOCKET_SIGNER_KEY;
if (!signerKey) {
  console.error("Error: SOCKET_SIGNER_KEY is required");
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

const ownableABI = OwnableArtifact.abi;

const wallet: Wallet = new ethers.Wallet(signerKey);
const signerAddress = wallet.address.toLowerCase();

export const main = async () => {
  await Promise.all(
    filteredChainSlugs.map(async (chainSlug) => {
      let chainAddresses: ChainSocketAddresses = addresses[chainSlug];

      let newOwner = chainAddresses["SocketSafeProxy"];
      if (!newOwner) {
        console.log(`❗ ${chainSlug}: SocketSafeProxy address not found`);
        return;
      }

      const provider = getProviderFromChainSlug(
        parseInt(chainSlug) as ChainSlug
      );
      const signer = wallet.connect(provider);

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
        await checkAndNominate(
          contractAddress,
          signer,
          chainSlug,
          label,
          newOwner
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
            await checkAndNominate(
              capAddress,
              signer,
              chainSlug,
              label,
              newOwner
            );
          }

          const decapAddress =
            chainAddresses.integrations[sibling][it]?.decapacitor;
          if (decapAddress) {
            const label = `${chainSlug}-${it}-${sibling}, Decap`;
            await checkAndNominate(
              decapAddress,
              signer,
              chainSlug,
              label,
              newOwner
            );
          }

          if (it === IntegrationTypes.native) {
            const sbAddress =
              chainAddresses.integrations[sibling][it]?.switchboard;
            if (sbAddress) {
              const label = `${chainSlug}-${it}-${sibling}, Switchboard`;
              await checkAndNominate(
                sbAddress,
                signer,
                chainSlug,
                label,
                newOwner
              );
            }
          }
        }
      }
    })
  );
};

const checkAndNominate = async (
  contractAddress: string,
  signer: Signer,
  chainSlug: string,
  label: string,
  newOwner: string
) => {
  label = label.padEnd(45);
  const contract = new ethers.Contract(
    contractAddress,
    ownableABI,
    signer
  ) as Ownable;

  const owner = (await contract.owner()).toLowerCase();
  const nominee = (await contract.nominee()).toLowerCase();

  console.log(` - ${label}: Checking: ${owner}, ${nominee}`);

  if (newOwner.toLowerCase() === owner.toLowerCase()) {
    console.log(` ✔ ${label}: Already claimed`);
    return;
  }

  if (newOwner.toLowerCase() === nominee.toLowerCase()) {
    console.log(` ✔ ${label}: Already nominated`);
    return;
  }

  if (signerAddress.toLowerCase() !== owner.toLowerCase()) {
    console.log(`❗ ${label}: Signer is not current owner`);
    return;
  }

  if (sendTx) {
    console.log(`✨ ${label}: Nominating`);
    const tx = await contract.nominateOwner(newOwner, {
      ...(await overrides(parseInt(chainSlug))),
    });
    const receipt = await tx.wait();
    console.log(`🚀 ${label}: Done: ${receipt.transactionHash}`);
  } else {
    console.log(`✨ ${label}: Needs nominating`);
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
