import {
  getDefaultIntegrationType,
  getProviderFromChainSlug,
} from "../constants";
import { getInstance } from "./utils";
import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  IntegrationTypes,
  MainnetIds,
  TestnetIds,
  getAllAddresses,
  isTestnet,
} from "../../src";
import { chains, mode } from "./config";
import { Contract, Wallet } from "ethers";
import { getSwitchboardAddress } from "../../src";
import { overrides } from "./config";
import { handleOps, isKinto } from "./utils/kinto/kinto";

export const main = async () => {
  try {
    let addresses: DeploymentAddresses = getAllAddresses(mode);

    await Promise.all(
      chains.map(async (chain) => {
        if (!addresses[chain]) return;

        const providerInstance = getProviderFromChainSlug(chain);
        const socketSigner: Wallet = new Wallet(
          process.env.SOCKET_SIGNER_KEY as string,
          providerInstance
        );

        const addr: ChainSocketAddresses = addresses[chain]!;
        if (!addr["integrations"]) return;

        const list = isTestnet(chain) ? TestnetIds : MainnetIds;
        const siblingSlugs: ChainSlug[] = list.filter(
          (chainSlug) =>
            chainSlug !== chain &&
            addresses?.[chainSlug]?.["Counter"] &&
            chains.includes(chainSlug)
        );

        const siblingIntegrationtype: IntegrationTypes[] = siblingSlugs.map(
          (chainSlug) => {
            return getDefaultIntegrationType(chain, chainSlug);
          }
        );

        console.log(`Configuring for ${chain}`);

        const counter: Contract = (
          await getInstance("Counter", addr["Counter"])
        ).connect(socketSigner);

        const socket: Contract = (
          await getInstance("Socket", addr["Socket"])
        ).connect(socketSigner);

        for (let index = 0; index < siblingSlugs.length; index++) {
          const sibling = siblingSlugs[index];
          const siblingCounter = addresses?.[sibling]?.["Counter"];
          let switchboard;
          try {
            switchboard = getSwitchboardAddress(
              chain,
              sibling,
              siblingIntegrationtype[index],
              mode
            );
          } catch (error) {
            console.log(error, " continuing");
          }
          if (!switchboard) continue;

          const configs = await socket.getPlugConfig(counter.address, sibling);
          if (
            configs["siblingPlug"].toLowerCase() ===
              siblingCounter?.toLowerCase() &&
            configs["inboundSwitchboard__"].toLowerCase() ===
              switchboard.toLowerCase()
          ) {
            console.log("Config already set!");
            continue;
          }

          let tx;
          const txRequest = await counter.populateTransaction.setSocketConfig(
            sibling,
            siblingCounter,
            switchboard,
            { ...overrides(chain) }
          );

          if (isKinto(chain)) {
            tx = await handleOps(
              process.env.SOCKET_OWNER_ADDRESS,
              [txRequest],
              process.env.SOCKET_SIGNER_KEY
            );
          } else {
            tx = await (await counter.signer.sendTransaction(txRequest)).wait();
          }

          console.log(
            `Connecting counter of ${chain} for ${sibling} and ${siblingIntegrationtype[index]} at tx hash: ${tx.transactionHash}`
          );
        }
      })
    );
  } catch (error) {
    console.log("Error while sending transaction", error);
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
