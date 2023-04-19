import hre from "hardhat";
import { deploySocket } from "./deploySocket";
import { ChainKey } from "../constants";

const chains = [ChainKey.HARDHAT];

/**
 * Deploys network-independent socket contracts
 */
export const main = async () => {
  try {
    await Promise.all(
      chains.map(async (chain) => {
        await hre.changeNetwork(chain);
        await deploySocket();
      })
    );
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
