import { ethers } from "hardhat";
import { Wallet } from "ethers";
import { ReturnObj, deploySocket } from "../scripts/deploySocket";
import { getProviderFromChainSlug } from "../../constants";
import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  getAllAddresses,
} from "../../../src";
import { mode } from "../config";

export const deployForChains = async (
  chains: ChainSlug[]
): Promise<ChainSocketAddresses[]> => {
  let deployedAddresses: ChainSocketAddresses[] = [];
  try {
    let addresses: DeploymentAddresses;
    try {
      addresses = getAllAddresses(mode);
    } catch (error) {
      addresses = {} as DeploymentAddresses;
    }

    await Promise.all(
      chains.map(async (chain: ChainSlug) => {
        let allDeployed = false;

        const providerInstance = getProviderFromChainSlug(chain);
        const signer: Wallet = new ethers.Wallet(
          process.env.SOCKET_SIGNER_KEY as string,
          providerInstance
        );

        let chainAddresses: ChainSocketAddresses = addresses[chain]
          ? (addresses[chain] as ChainSocketAddresses)
          : ({} as ChainSocketAddresses);

        while (!allDeployed) {
          const results: ReturnObj = await deploySocket(
            signer,
            chain,
            mode,
            chainAddresses
          );

          allDeployed = results.allDeployed;
          chainAddresses = results.deployedAddresses;

          deployedAddresses[chain] = chainAddresses;
        }
      })
    );
  } catch (error) {
    console.log("Error in deploying setup contracts", error);
  }

  return deployedAddresses;
};
