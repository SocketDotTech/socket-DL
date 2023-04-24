import hre from "hardhat";
import { networkToChainSlug, switchboards } from "../constants";
import { getInstance, getSigners } from "./utils";
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
import { mode } from "./config";
import { Contract } from "ethers";
import { getSwitchboardAddress } from "../../src";

const chains = [...TestnetIds, ...MainnetIds];

export const main = async () => {
  try {
    let addresses: DeploymentAddresses = getAllAddresses(mode);
    let chain: ChainSlug;

    for (chain of chains) {
      if (!addresses[chain]) continue;

      await hre.changeNetwork(networkToChainSlug[chain]);
      const { socketSigner } = await getSigners();

      const addr: ChainSocketAddresses = addresses[chain]!;
      if (!addr["integrations"]) continue;

      const list = isTestnet(chain) ? TestnetIds : MainnetIds;
      const siblingSlugs: ChainSlug[] = list.filter(
        (chainSlug) =>
          chainSlug !== chain && addresses?.[chainSlug]?.["Counter"]
      );

      const siblingIntegrationtype: IntegrationTypes[] = siblingSlugs.map(
        (chainSlug) => {
          return switchboards[networkToChainSlug[chain]][
            networkToChainSlug[chainSlug]
          ]
            ? IntegrationTypes.native
            : IntegrationTypes.fast;
        }
      );

      console.log(`Configuring for ${chain}`);

      const counter: Contract = (
        await getInstance("Counter", addr["Counter"])
      ).connect(socketSigner);

      for (let index = 0; index < siblingSlugs.length; index++) {
        const sibling = siblingSlugs[index];
        const tx = await counter.setSocketConfig(
          sibling,
          addresses?.[sibling]?.["Counter"],
          getSwitchboardAddress(
            chain,
            sibling,
            siblingIntegrationtype[index],
            mode
          )
        );

        console.log(
          `Connecting counter of ${chain} for ${sibling} and ${siblingIntegrationtype[index]} at tx hash: ${tx.hash}`
        );
        await tx.wait();
      }
    }
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
