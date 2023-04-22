import { ethers } from "hardhat";
import { Wallet } from "ethers";
import { deploySocket } from "./scripts/deploySocket";
import { ChainKey, chainSlugs, getProviderFromChainName } from "../constants";
import { storeVerificationParams } from "./utils";
import {
  ChainSocketAddresses,
  DeploymentAddresses,
  getAllAddresses,
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
      chains.map(async (chain: ChainKey) => {
        let allDeployed = false;

        while (!allDeployed) {
          const providerInstance = getProviderFromChainName(chain);
          const signer: Wallet = new ethers.Wallet(
            process.env.SOCKET_SIGNER_KEY as string,
            providerInstance
          );

          let chainAddresses = addresses[chain]
            ? addresses[chain]
            : ({} as ChainSocketAddresses);

          const results = await deploySocket(
            signer,
            chain,
            mode,
            chainAddresses
          );

          await storeVerificationParams(
            results.verificationDetails,
            chainSlugs[chain],
            mode
          );
          allDeployed = results.allDeployed;
          addresses[chain] = results.addresses;

          console.log(addresses);
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
