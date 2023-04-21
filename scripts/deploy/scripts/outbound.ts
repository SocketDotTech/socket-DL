import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import fs from "fs";
import { getNamedAccounts, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { getInstance, getChainSlug, deployedAddressPath } from "../utils";
import { Contract } from "ethers";
import { DeploymentMode } from "../../constants";

const remoteChainSlug = "";
const mode = process.env.DEPLOYMENT_MODE as DeploymentMode | DeploymentMode.DEV;

export const main = async () => {
  try {
    const chainSlug = await getChainSlug();
    const amount = 100;
    const msgGasLimit = "19000000";
    const gasLimit = 200485;
    const fees = "20000000000000000";

    const config: any = JSON.parse(
      fs.readFileSync(deployedAddressPath(mode), "utf-8")
    );

    const { counterOwner } = await getNamedAccounts();
    const signer: SignerWithAddress = await ethers.getSigner(counterOwner);

    const counter: Contract = await getInstance(
      "Counter",
      config[chainSlug]["Counter"]
    );
    await counter
      .connect(signer)
      .remoteAddOperation(remoteChainSlug, amount, msgGasLimit, {
        gasLimit,
        value: fees,
      });

    console.log(
      `Sent remoteAddOperation with ${amount} amount and ${msgGasLimit} gas limit to counter at ${remoteChainSlug}`
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
