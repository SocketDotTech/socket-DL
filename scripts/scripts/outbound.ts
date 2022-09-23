import fs from "fs";
import { getNamedAccounts, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { getInstance, getChainId, deployedAddressPath } from "../utils";
import { Contract } from "ethers";
import { destChainId } from "../config";

export const main = async () => {
  try {
    const chainId = await getChainId();
    const amount = 100
    const msgGasLimit = "19000000"

    if (!fs.existsSync(deployedAddressPath + chainId + ".json")) {
      throw new Error("Deployed Addresses not found");
    }

    const config: any = JSON.parse(fs.readFileSync(deployedAddressPath + chainId + ".json", "utf-8"));

    const { user } = await getNamedAccounts();
    const signer: SignerWithAddress = await ethers.getSigner(user);

    const counter: Contract = await getInstance("Counter", config["counter"]);
    await counter.connect(signer).remoteAddOperation(destChainId, amount, msgGasLimit);

    console.log(`Sent remoteAddOperation with ${amount} amount and ${msgGasLimit} gas limit to counter at ${destChainId}`);
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
