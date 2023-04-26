import { ethers } from "hardhat";
import { getInstance, getChainSlug } from "../utils";
import { Contract } from "ethers";
import {
  ChainSlug,
  getSwitchboardAddress,
  IntegrationTypes,
} from "../../../src";
import { mode } from "../config";

export const main = async () => {
  try {
    const chainSlug = await getChainSlug();
    const srcChainSlug = ChainSlug.GOERLI;
    const privateKey = "";

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

    const untripTxn = await switchboard
      .connect(signer)
    ["tripPath(uint256,bool)"](srcChainSlug, false);
    await untripTxn.wait();

    const isTripped = await switchboard.tripSinglePath(srcChainSlug);

    console.log(
      `trip indicator for srcChainSlug: ${srcChainSlug} and switchBoard on ChainSlug: ${chainSlug} is: ${isTripped}`
    );
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
