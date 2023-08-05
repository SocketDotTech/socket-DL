import { ethers } from "hardhat";
import { Wallet } from "ethers";
import { ReturnObj, deploySocket } from "./scripts/deploySocket";
import { getProviderFromChainName } from "../constants";
import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  getAllAddresses,
  ChainSlugToKey,
} from "../../src";
import { chains, mode } from "./config";

/**
 * Deploys network-independent socket contracts
 */
export const main = async () => {
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
        const network = ChainSlugToKey[chain];

        const providerInstance = getProviderFromChainName(network);
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
        }
      })
    );
  } catch (error) {
    console.log("Error in deploying setup contracts", error);
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
