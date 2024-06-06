import { config as dotenvConfig } from "dotenv";
dotenvConfig();

import fs from "fs";
import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import {
  getInstance,
  getChainSlug,
  deployedAddressPath,
  deployContractWithArgs,
} from "../deploy/utils";
import { Contract } from "ethers";
import { mode } from "../deploy/config/config";

export const main = async () => {
  try {
    const chainSlug = await getChainSlug();
    if (!fs.existsSync(deployedAddressPath(mode) + chainSlug + ".json")) {
      throw new Error("Deployed Addresses not found");
    }

    const config: any = JSON.parse(
      fs.readFileSync(deployedAddressPath(mode) + chainSlug + ".json", "utf-8")
    );

    const socketSigners: SignerWithAddress = await ethers.getSigners();
    const socketSigner = socketSigners[0];

    const notary = await getInstance("AdminNotary", config["notary"]);
    const signatureVerifier: Contract = await deployContractWithArgs(
      "SignatureVerifier",
      [],
      socketSigner
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
