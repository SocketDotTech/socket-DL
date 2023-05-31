import {
  getDefaultIntegrationType,
  getProviderFromChainName,
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
  networkToChainSlug,
} from "../../src";
import { mode } from "./config";
import { Contract, Wallet } from "ethers";
import { getSwitchboardAddress } from "../../src";
import { overrides } from "./config";

const chains = [...TestnetIds, ...MainnetIds];

export const main = async () => {
  try {
    let addresses: DeploymentAddresses = getAllAddresses(mode);
    let chain: ChainSlug;

    await Promise.all(
      chains.map(async (chain) => {
        if (!addresses[chain]) return;

        const providerInstance = getProviderFromChainName(
          networkToChainSlug[chain]
        );
        const socketSigner: Wallet = new Wallet(
          process.env.SOCKET_SIGNER_KEY as string,
          providerInstance
        );

        const addr: ChainSocketAddresses = addresses[chain]!;
        if (!addr["integrations"]) return;

        const list = isTestnet(chain) ? TestnetIds : MainnetIds;
        const siblingSlugs: ChainSlug[] = list.filter(
          (chainSlug) =>
            chainSlug !== chain && addresses?.[chainSlug]?.["Counter"]
        );

        const siblingIntegrationtype: IntegrationTypes[] = siblingSlugs.map(
          (chainSlug) => {
            return getDefaultIntegrationType(
              networkToChainSlug[chain],
              networkToChainSlug[chainSlug]
            );
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
          const switchboard = getSwitchboardAddress(
            chain,
            sibling,
            siblingIntegrationtype[index],
            mode
          );

          const configs = await socket.getPlugConfig(counter.address, sibling);
          if (
            configs["siblingPlug"].toLowerCase() ===
              siblingCounter?.toLowerCase() &&
            configs["inboundSwitchboard__"].toLowerCase() ===
              switchboard.toLowerCase()
          ) {
            console.log("Config already set!");
            return;
          }

          const tx = await counter.setSocketConfig(
            sibling,
            siblingCounter,
            switchboard,
            { ...overrides[chain] }
          );

          console.log(
            `Connecting counter of ${chain} for ${sibling} and ${siblingIntegrationtype[index]} at tx hash: ${tx.hash}`
          );
          await tx.wait();
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
