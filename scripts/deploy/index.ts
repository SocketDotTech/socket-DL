import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import { ethers } from "hardhat";
import { Wallet } from "ethers";
import { deploySocket } from "./scripts/deploySocket";
import { ChainKey, chainSlugs, getProviderFromChainName } from "../constants";
import { storeVerificationParams } from "./utils";
import { ChainSocketAddresses, DeploymentMode, getAddresses } from "../../src";

const chains: Array<ChainKey> = [
  ChainKey.GOERLI,
  ChainKey.ARBITRUM_GOERLI,
  ChainKey.OPTIMISM_GOERLI,
  ChainKey.POLYGON_MUMBAI,
  ChainKey.BSC_TESTNET,
];

const mode = process.env.DEPLOYMENT_MODE as DeploymentMode | DeploymentMode.DEV;

/**
 * Deploys network-independent socket contracts
 */
export const main = async () => {
  try {
    await Promise.all(
      chains.map(async (chain: ChainKey) => {
        const addresses: ChainSocketAddresses = getAddresses(
          chainSlugs[chain],
          mode
        )
          ? getAddresses(chainSlugs[chain], mode)
          : ({} as ChainSocketAddresses);

        let allDeployed = false;
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
