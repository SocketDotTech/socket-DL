import { getDefaultIntegrationType } from "../../constants";
import { getInstance } from "../utils";
import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  IntegrationTypes,
  MainnetIds,
  TestnetIds,
  isTestnet,
} from "../../../src";
import { Contract } from "ethers";
import { getSwitchboardAddressFromAllAddresses } from "../../../src";
import { overrides } from "../config/config";
import { getSocketSigner } from "../utils/socket-signer";

export const connectPlugs = async (
  addresses: DeploymentAddresses,
  chains: ChainSlug[]
) => {
  try {
    await Promise.all(
      chains.map(async (chain) => {
        if (!addresses[chain]) return;

        const addr: ChainSocketAddresses = addresses[chain]!;
        const socketSigner = await getSocketSigner(chain, addr, false);

        if (!addr["integrations"]) return;

        const list = isTestnet(chain) ? TestnetIds : MainnetIds;
        const siblingSlugs: ChainSlug[] = list.filter(
          (chainSlug) =>
            chainSlug !== chain &&
            addresses?.[chainSlug]?.["Counter"] &&
            chains.includes(chainSlug)
        );

        const siblingIntegrationType: IntegrationTypes[] = siblingSlugs.map(
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

        const owner = await counter.owner();
        if (owner.toLowerCase() !== socketSigner.address.toLowerCase()) return;

        for (let index = 0; index < siblingSlugs.length; index++) {
          const sibling = siblingSlugs[index];
          const siblingCounter = addresses?.[sibling]?.["Counter"];
          let switchboard;
          try {
            switchboard = getSwitchboardAddressFromAllAddresses(
              addresses,
              chain,
              sibling,
              siblingIntegrationType[index]
            );
          } catch (error) {
            console.log(error, " continuing");
          }
          if (!switchboard) continue;

          const configs = await socket.getPlugConfig(counter.address, sibling, {
            ...(await overrides(chain)),
          });
          if (
            configs["siblingPlug"].toLowerCase() ===
              siblingCounter?.toLowerCase() &&
            configs["inboundSwitchboard__"].toLowerCase() ===
              switchboard.toLowerCase()
          ) {
            console.log("Config already set!");
            continue;
          }

          const tx = await counter.setSocketConfig(
            sibling,
            siblingCounter,
            switchboard,
            { ...(await overrides(chain)) }
          );

          console.log(
            `Connecting counter of ${chain} for ${sibling} and ${siblingIntegrationType[index]} at tx hash: ${tx.hash}`
          );
          await tx.wait();
        }
      })
    );
  } catch (error) {
    console.log("Error while sending transaction", error);
  }
};
