import hre, { ethers } from "hardhat";
import { deploySocket } from "./deploySocket";
import { ChainKey, chainSlugs, getProviderFromChainName } from "../constants";
import { Wallet } from "ethers";
import { storeVerificationParams, verify } from "./utils";

const chains: Array<ChainKey> = [
  ChainKey.GOERLI,
  ChainKey.ARBITRUM_GOERLI,
  ChainKey.OPTIMISM_GOERLI,
  ChainKey.POLYGON_MUMBAI,
  ChainKey.BSC_TESTNET,
];

export type VerifyParams = { [chain in ChainKey]?: any[][] };
let verificationDetails: VerifyParams = {};

/**
 * Deploys network-independent socket contracts
 */
export const main = async () => {
  try {
    await Promise.all(
      chains.map(async (chain: ChainKey) => {
        let allDeployed = false;
        while (!allDeployed) {
          const providerInstance = getProviderFromChainName(chain);
          const signer: Wallet = new ethers.Wallet(
            process.env.SOCKET_SIGNER_KEY as string,
            providerInstance
          );

          const results = await deploySocket(signer, chain);

          await storeVerificationParams(
            results.verificationDetails,
            chainSlugs[chain]
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
