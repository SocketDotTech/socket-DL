import { ethers } from "hardhat";
import { getInstance, getChainSlug } from "../utils";
import { Contract } from "ethers";
import {
  ChainSlug,
  getSwitchboardAddress,
  IntegrationTypes,
} from "../../../src";
import { mode } from "../config";

const srcChainSlug = ChainSlug.GOERLI;
const privateKey = process.env.SOCKET_SIGNER_KEY;

// update the inputs to the
export const main = async () => {
  try {
    const chainSlug = await getChainSlug();
    const signer = new ethers.Wallet(privateKey, ethers.provider);

    const switchBoardAddress = getSwitchboardAddress(
      chainSlug,
      srcChainSlug,
      IntegrationTypes.fast,
      mode
    );

    const switchboard: Contract = await getInstance(
      "FastSwitchboard",
      switchBoardAddress
    );

    const unTripTxn = await switchboard
      .connect(signer)
      ["tripPath(uint256,bool)"](srcChainSlug, false);
    await unTripTxn.wait();

    const isTripped = await switchboard.tripSinglePath(srcChainSlug);

    console.log(
      `trip indicator for srcChainSlug: ${srcChainSlug} and switchBoard on ChainSlug: ${chainSlug} is: ${isTripped}`
    );
  } catch (error) {
    console.log("Error while sending unTrip transaction", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
