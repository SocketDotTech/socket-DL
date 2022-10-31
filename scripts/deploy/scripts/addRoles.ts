import fs from "fs";
import { getNamedAccounts, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { getInstance, getChainId, deployedAddressPath } from "../utils";
import { Contract } from "ethers";
import { remoteChainId, executorAddress, attesterAddress } from "../config";

export const main = async () => {
  try {
    const chainId = await getChainId();

    if (!fs.existsSync(deployedAddressPath + chainId + ".json")) {
      throw new Error("Deployed Addresses not found");
    }

    const config: any = JSON.parse(fs.readFileSync(deployedAddressPath + chainId + ".json", "utf-8"));

    const { socketOwner } = await getNamedAccounts();
    const signer: SignerWithAddress = await ethers.getSigner(socketOwner);

    const notary: Contract = await getInstance("AdminNotary", config["notary"]);
    const socket: Contract = await getInstance("Socket", config["socket"]);

    await notary.connect(signer).grantAttesterRole(remoteChainId, attesterAddress[chainId]);
    await socket.connect(signer).grantExecutorRole(executorAddress[chainId]);
    console.log(`Assigned roles to ${executorAddress[chainId]}!`)
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
