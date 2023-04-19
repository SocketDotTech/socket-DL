import hre, { ethers } from "hardhat";
import { deploySocket } from "./deploySocket";
import { ChainKey, getProviderFromChainName } from "../constants";
import { Wallet } from "ethers";
import { verify } from "./utils";

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
        const providerInstance = getProviderFromChainName(chain);
        const signer: Wallet = new ethers.Wallet(
          process.env.SOCKET_SIGNER_KEY as string,
          providerInstance
        );

        verificationDetails[chain] = await deploySocket(signer, chain);
      })
    );

    for (let chainIndex = 0; chainIndex < chains.length; chainIndex++) {
      const chain = chains[chainIndex];
      hre.changeNetwork(chain);

      if (
        verificationDetails &&
        verificationDetails[chain] &&
        verificationDetails[chain]?.length
      ) {
        const len = verificationDetails[chain]?.length;
        for (let index = 0; index < len!; index++)
          await verify(...verificationDetails[chain][index]);
      }
    }
  } catch (error) {
    console.log("Error in deploying setup contracts", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
