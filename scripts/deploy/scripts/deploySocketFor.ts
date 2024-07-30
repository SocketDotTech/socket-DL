import { ReturnObj, deploySocket } from "../scripts/deploySocket";
import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  getAllAddresses,
} from "../../../src";
import { mode } from "../config/config";
import { storeAddresses } from "../utils";
import { SocketSigner } from "@socket.tech/dl-common";
import { getSocketSigner } from "../utils/socket-signer";

export const deployForChains = async (
  chains: ChainSlug[],
  executionManagerVersion: string
): Promise<DeploymentAddresses> => {
  let addresses: DeploymentAddresses;
  try {
    try {
      addresses = getAllAddresses(mode);
    } catch (error) {
      addresses = {} as DeploymentAddresses;
    }

    await Promise.all(
      chains.map(async (chain: ChainSlug) => {
        let allDeployed = false;

        let chainAddresses: ChainSocketAddresses = addresses[chain]
          ? (addresses[chain] as ChainSocketAddresses)
          : ({} as ChainSocketAddresses);

        const signer: SocketSigner = await getSocketSigner(
          chain,
          chainAddresses
        );

        while (!allDeployed) {
          const results: ReturnObj = await deploySocket(
            executionManagerVersion,
            signer,
            chain,
            mode,
            chainAddresses
          );

          await storeAddresses(results.deployedAddresses, chain, mode);

          allDeployed = results.allDeployed;
          chainAddresses = results.deployedAddresses;
          addresses[chain] = results.deployedAddresses;
        }
      })
    );
  } catch (error) {
    console.log("Error in deploying setup contracts", error);
    throw error;
  }

  return addresses;
};
