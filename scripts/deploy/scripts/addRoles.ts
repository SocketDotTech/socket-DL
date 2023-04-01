import fs from "fs";
import { getNamedAccounts, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { getInstance, getChainSlug, deployedAddressPath } from "../utils";
import { Contract } from "ethers";
import { executorAddress, attesterAddress } from "../config";

const remoteChainSlug = "";

export const main = async () => {
  try {
    const chainSlug = await getChainSlug();

    if (!fs.existsSync(deployedAddressPath + chainSlug + ".json")) {
      throw new Error("Deployed Addresses not found");
    }

    const config: any = JSON.parse(
      fs.readFileSync(deployedAddressPath + chainSlug + ".json", "utf-8")
    );

    const { socketOwner } = await getNamedAccounts();
    const signer: SignerWithAddress = await ethers.getSigner(socketOwner);

    const notary: Contract = await getInstance("AdminNotary", config["notary"]);
    const socket: Contract = await getInstance("Socket", config["socket"]);

    await notary
      .connect(signer)
      .grantAttesterRole(remoteChainSlug, attesterAddress[chainSlug]);
    await socket.connect(signer).grantExecutorRole(executorAddress[chainSlug]);
    console.log(`Assigned roles to ${executorAddress[chainSlug]}!`);
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
