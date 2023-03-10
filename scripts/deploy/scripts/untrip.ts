import { ethers } from "hardhat";
import { getInstance, getChainId } from "../utils";
import { Contract } from "ethers";
import { ChainId, getSwitchboardAddress, IntegrationTypes } from "../../../src";

export const main = async () => {
  try {
    const chainId = await getChainId();
    const srcChainId = ChainId.GOERLI;
    const privateKey = '';

    const signer = new ethers.Wallet(privateKey, ethers.provider);

    const switchBoardAddress = getSwitchboardAddress(chainId, srcChainId, IntegrationTypes.fast);

    const switchboard: Contract = await getInstance("FastSwitchboard", switchBoardAddress);

    const untripTxn = await switchboard.connect(signer)["tripPath(uint256,bool)"](srcChainId, false);
    await untripTxn.wait();

    const isTripped = await switchboard.tripSinglePath(srcChainId);

    console.log(`trip indicator for srcChainId: ${srcChainId} and switchBoard on ChainId: ${chainId} is: ${isTripped}`);

  } catch (error) {
    console.log("Error while sending untrip transaction", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
