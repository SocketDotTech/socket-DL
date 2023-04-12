import fs from "fs";
import { getNamedAccounts, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import {
  getInstance,
  deployContractWithoutArgs,
  getChainSlug,
  deployedAddressPath,
} from "../utils";
import { Contract } from "ethers";

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

    const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);
    const notary = await getInstance("AdminNotary", config["notary"]);

    const signatureVerifier: Contract = await deployContractWithoutArgs(
      "SignatureVerifier",
      socketSigner,
      "contracts/utils/SignatureVerifier.sol"
    );
    console.log(
      signatureVerifier.address,
      `Deployed signatureVerifier for ${chainSlug}`
    );

    await notary
      .connect(socketSigner)
      .setSignatureVerifier(signatureVerifier.address);
    console.log(
      `Updated signatureVerifier in notary ${signatureVerifier.address}`
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
