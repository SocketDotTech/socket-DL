import fs from "fs";
import { getNamedAccounts, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { signerAddress, destChainId, isFast } from "./config";
import { getInstance, deployedAddressPath, getChainId } from "./utils";
import { Contract } from "ethers";

export const main = async () => {
  try {
    const srcChainId = await getChainId();

    if (!destChainId)
      throw new Error("Provide destination chain id");

    if (!fs.existsSync(deployedAddressPath + srcChainId + ".json") || !fs.existsSync(deployedAddressPath + destChainId + ".json")) {
      throw new Error("Deployed Addresses not found");
    }

    let srcConfig: JSON = JSON.parse(fs.readFileSync(deployedAddressPath + srcChainId + ".json", "utf-8"));
    const destConfig: JSON = JSON.parse(fs.readFileSync(deployedAddressPath + destChainId + ".json", "utf-8"))

    const { socketSigner, counterSigner } = await getSigners();

    const counter: Contract = await getInstance("Counter", srcConfig["counter"]);
    const socket: Contract = await getInstance("Socket", srcConfig["socket"]);

    const accum = isFast ? "FAST" : "SLOW"
    await configSocket(socket, socketSigner, destChainId, srcConfig);
    await configNotary(srcConfig["notary"], socketSigner)

    await counter.connect(counterSigner).setSocketConfig(
      destChainId,
      destConfig["counter"],
      accum
    );
    console.log(`Set config for ${destChainId} chain id!`)

  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

async function configNotary(notaryAddr: string, socketSigner: SignerWithAddress) {
  try {
    const srcChainId = await getChainId();
    const notary: Contract = await getInstance("AdminNotary", notaryAddr);
    await notary.connect(socketSigner).grantAttesterRole(destChainId, signerAddress[srcChainId]);
    console.log(`Added ${signerAddress[srcChainId]} as an attester for ${destChainId} chain id!`)
  } catch (error) {
    console.log("Error while configuring Notary", error);
    throw error;
  }
}

async function getSigners() {
  const { socketOwner, counterOwner } = await getNamedAccounts();
  const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);
  const counterSigner: SignerWithAddress = await ethers.getSigner(counterOwner);
  return { socketSigner, counterSigner };
}

async function configSocket(socket: Contract, socketSigner: SignerWithAddress, destChainId: number, srcConfig: JSON) {
  try {
    await socket.connect(socketSigner).addConfig(
      destChainId,
      srcConfig[`fastAccum-${destChainId}`],
      srcConfig[`deaccum-${destChainId}`],
      srcConfig["verifier"],
      "FAST"
    );

    await socket.connect(socketSigner).addConfig(
      destChainId,
      srcConfig[`slowAccum-${destChainId}`],
      srcConfig[`deaccum-${destChainId}`],
      srcConfig["verifier"],
      "SLOW"
    );

    console.log(`Added slow and fast config for ${destChainId} chain id!`)

  } catch (error) {
    console.log("Error while configuring socket", error);
    throw error;
  }
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
