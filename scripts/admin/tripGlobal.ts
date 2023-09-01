import { Contract, Wallet, utils } from "ethers";
import { StaticJsonRpcProvider } from "@ethersproject/providers";
import {
  IntegrationTypes,
  ChainSlug,
  getSwitchboardAddress,
  DeploymentMode,
} from "../../src";
import { chains, mode, overrides } from "../deploy/config";
import { getABI } from "../deploy/scripts/getABIs";
import { getProviderFromChainSlug } from "../constants";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";

const main = async (chainToBeTripped: ChainSlug) => {
  for (const chain of chains) {
    if (chainToBeTripped != chain) continue;

    for (const siblingChain of chains) {
      for (const integrationType of Object.values(IntegrationTypes)) {
        if (integrationType === IntegrationTypes.native) continue;
        const switchboard = getSwitchboardInstance(
          chain,
          siblingChain,
          integrationType,
          mode
        );
        if (switchboard === undefined) continue;

        console.log("Checking", { dst: chain }, { type: integrationType });

        const tripStatus = await switchboard.isGlobalTipped();

        if (tripStatus == true) {
          console.log("already tripped, continue");
          continue;
        }

        console.log("tripping", { chain });

        const nonce = await switchboard.nextNonce(
          switchboard.signer.getAddress()
        );
        const digest = keccak256(
          defaultAbiCoder.encode(
            ["bytes32", "address", "uint32", "uint256", "bool"],
            [utils.id("TRIP_GLOBAL"), switchboard.address, chain, nonce, true]
          )
        );

        const signature = await switchboard.signer.signMessage(
          arrayify(digest)
        );

        const tx = await switchboard.tripGlobal(nonce, signature, {
          ...overrides[chain],
        });
        console.log(tx.hash);

        await tx.wait();
        console.log("done");
      }
      break; // as global trip, check for a single siblingChain is enough
    }
  }
};

const sbContracts: { [key: string]: Contract } = {};
const getSwitchboardInstance = (
  chain: ChainSlug,
  siblingChain: ChainSlug,
  integrationType: IntegrationTypes,
  mode: DeploymentMode
): Contract | undefined => {
  let switchboardAddress: string;
  try {
    switchboardAddress = getSwitchboardAddress(
      chain,
      siblingChain,
      integrationType,
      mode
    );
  } catch (e) {
    // means no switchboard found for given params
    return;
  }
  if (!sbContracts[`${chain}${siblingChain}${switchboardAddress}`]) {
    const provider: StaticJsonRpcProvider = getProviderFromChainSlug(chain);
    if (!process.env.SOCKET_SIGNER_KEY)
      throw new Error("SOCKET_SIGNER_KEY not set");
    const signer: Wallet = new Wallet(process.env.SOCKET_SIGNER_KEY, provider);

    sbContracts[`${chain}${siblingChain}${switchboardAddress}`] = new Contract(
      switchboardAddress,
      getABI.FastSwitchboard,
      signer
    );
  }
  return sbContracts[`${chain}${siblingChain}${switchboardAddress}`];
};

const chainToBeTripped = ChainSlug.OPTIMISM_GOERLI;

main(chainToBeTripped)
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
