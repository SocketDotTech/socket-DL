import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import fs from "fs";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { utils, constants } from "ethers";
import { getInstance, getChainSlug, deployedAddressPath } from "../utils";
import { Contract } from "ethers";
import { mode } from "../config";

const remoteChainSlug = "";

export const main = async () => {
  try {
    const chainSlug = await getChainSlug();
    const amount = 100;
    const msgGasLimit = "19000000";
    const gasLimit = "200485";
    const fees = "2000000000000";

    const config: any = JSON.parse(
      fs.readFileSync(deployedAddressPath(mode), "utf-8")
    );

    const socketSigners: SignerWithAddress = await ethers.getSigners();
    const signer = socketSigners[0];

    const counter: Contract = await getInstance(
      "Counter",
      config[chainSlug]["Counter"]
    );
    const tx = await counter
      .connect(signer)
      .remoteAddOperation(
        remoteChainSlug,
        amount,
        msgGasLimit,
        constants.HashZero,
        constants.HashZero,
        {
          value: fees,
        }
      );

    await tx.wait();
    console.log(
      `Sent remoteAddOperation with ${amount} amount and ${msgGasLimit} gas limit to counter at ${remoteChainSlug}, tx hash: ${tx.hash.toLowerCase()}`
    );
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
