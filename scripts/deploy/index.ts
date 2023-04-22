import { ethers } from "hardhat";
import { Wallet } from "ethers";
import { deploySocket } from "./scripts/deploySocket";
import { ChainKey, chainSlugs, getProviderFromChainName } from "../constants";
import { storeVerificationParams } from "./utils";
import { ChainSocketAddresses, getAddresses } from "../../src";
import { chains, mode } from "./config";

/**
 * Deploys network-independent socket contracts
 */
export const main = async () => {
  try {
    await Promise.all(
      chains.map(async (chain: ChainKey) => {
        let allDeployed = false;
        let addresses: ChainSocketAddresses;
        try {
          addresses = getAddresses(chainSlugs[chain], mode);
        } catch (error) {
          addresses = {} as ChainSocketAddresses;
        }

        while (!allDeployed) {
          const providerInstance = getProviderFromChainName(chain);
          const signer: Wallet = new ethers.Wallet(
            process.env.SOCKET_SIGNER_KEY as string,
            providerInstance
          );

          const results = await deploySocket(signer, chain, mode, addresses);
          await storeVerificationParams(
            results.verificationDetails,
            chainSlugs[chain],
            mode
          );
          allDeployed = results.allDeployed;
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
