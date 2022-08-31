import fs from "fs";
import path from "path";
import { getNamedAccounts, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { isSequential, signerAddress, srcChainId, destChainId } from "./config";
import { getInstance } from "./utils";

const deployedAddressPath = path.join(__dirname, "../deployments/");

export const main = async () => {
  try {
    if (!srcChainId || !destChainId)
      throw new Error("Provide chain id");

    if (!fs.existsSync(deployedAddressPath + srcChainId + ".json") || !fs.existsSync(deployedAddressPath + destChainId + ".json")) {
      throw new Error("Deployed Addresses not found");
    }

    const srcConfig: any = JSON.parse(fs.readFileSync(deployedAddressPath + srcChainId + ".json", "utf-8"));
    const destConfig: any = JSON.parse(fs.readFileSync(deployedAddressPath + destChainId + ".json", "utf-8"))

    const { socketOwner, counterOwner, pauser } = await getNamedAccounts();

    const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);
    const counterSigner: SignerWithAddress = await ethers.getSigner(counterOwner);
    const pauserSigner: SignerWithAddress = await ethers.getSigner(pauser);

    const notary = await getInstance("AdminNotary", srcConfig["notary"]);
    const counter = await getInstance("Counter", srcConfig["counter"]);
    const accum = await getInstance("SingleAccum", srcConfig["accum"]);
    const deaccum = await getInstance("SingleDeaccum", srcConfig["deaccum"]);
    const verifier = await getInstance("AcceptWithTimeout", srcConfig["verifier"]);

    await notary.connect(socketSigner).grantSignerRole(destChainId, signerAddress[srcChainId]);
    console.log(`Granted ${signerAddress[srcChainId]} role for ${destChainId} chain id!`)

    await counter.connect(counterSigner).setSocketConfig(
      destChainId,
      destConfig["counter"],
      accum.address,
      deaccum.address,
      verifier.address,
      isSequential
    );
    console.log(`Granted ${signerAddress[srcChainId]} role for ${destChainId} chain id!`)

    await verifier.connect(counterSigner).AddPauser(pauserSigner.address, destChainId);
    console.log(`Added pauser ${pauserSigner.address} for ${destChainId} chain id!`)

    await verifier.connect(pauserSigner).Activate(destChainId);
    console.log(`Activated verifier for ${destChainId} chain id!`)
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
