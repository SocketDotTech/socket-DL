import fs from "fs";
import path from "path";
import { getNamedAccounts, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { srcChainId } from "../config";
import { getInstance, deployContractWithoutArgs } from "../utils";
import { Contract } from "ethers";

const deployedAddressPath = path.join(__dirname, "../../deployments/");

export const main = async () => {
  try {
    if (!srcChainId)
      throw new Error("Provide chain id");

    if (!fs.existsSync(deployedAddressPath + srcChainId + ".json")) {
      throw new Error("Deployed Addresses not found");
    }

    const config: any = JSON.parse(fs.readFileSync(deployedAddressPath + srcChainId + ".json", "utf-8"));
    const { socketOwner } = await getNamedAccounts();

    const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);
    const notary = await getInstance("AdminNotary", config["notary"]);

    const signatureVerifier: Contract = await deployContractWithoutArgs("SignatureVerifier", socketSigner);
    console.log(signatureVerifier.address, `Deployed signatureVerifier for ${srcChainId}`);
  
    await notary.connect(socketSigner).setSignatureVerifier(signatureVerifier.address);
    console.log(`Updated signatureVerifier in notary ${signatureVerifier.address}`)
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
