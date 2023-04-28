import { ethers } from "hardhat";
import { Wallet } from "ethers";
import { deploySocket } from "./scripts/deploySocket";
import { getProviderFromChainName } from "../constants";
import { storeVerificationParams } from "./utils";
import {
  ChainSlug,
  ChainSocketAddresses,
  DeploymentAddresses,
  getAllAddresses,
  networkToChainSlug,
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
        const network = networkToChainSlug[chain];

        while (!allDeployed) {
          const providerInstance = getProviderFromChainName(network);
          const signer: Wallet = new ethers.Wallet(
            process.env.SOCKET_SIGNER_KEY as string,
            providerInstance
          );

          const chainAddresses: ChainSocketAddresses = addresses[chain]
            ? (addresses[chain] as ChainSocketAddresses)
            : ({} as ChainSocketAddresses);

          const results = await deploySocket(
            signer,
            chain,
            mode,
            chainAddresses
          );

          await storeVerificationParams(
            results.verificationDetails,
            chain,
            mode
          );
          allDeployed = results.allDeployed;
          addresses[network] = results.addresses;
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
