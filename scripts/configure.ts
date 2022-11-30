import fs from "fs";
import { getNamedAccounts, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { attesterAddress, remoteChainId, isFast, fastIntegration, slowIntegration } from "./config";
import { getInstance, deployedAddressPath, getChainId } from "./utils";
import { Contract } from "ethers";

export const main = async () => {
  try {
    const localChainId = await getChainId();

    if (!remoteChainId)
      throw new Error("Provide remote chain id");

    if (!fs.existsSync(deployedAddressPath + localChainId + ".json") || !fs.existsSync(deployedAddressPath + remoteChainId + ".json")) {
      throw new Error("Deployed Addresses not found");
    }

    let localConfig: JSON = JSON.parse(fs.readFileSync(deployedAddressPath + localChainId + ".json", "utf-8"));
    const remoteConfig: JSON = JSON.parse(fs.readFileSync(deployedAddressPath + remoteChainId + ".json", "utf-8"))

    const { socketSigner, counterSigner } = await getSigners();

    const counter: Contract = await getInstance("Counter", localConfig["counter"]);
    const socket: Contract = await getInstance("Socket", localConfig["socket"]);

    const accum = isFast ? fastIntegration : slowIntegration
    await configSocket(socket, socketSigner, remoteChainId, localConfig);
    await configNotary(localConfig["notary"], socketSigner)

    await counter.connect(counterSigner).setSocketConfig(
      remoteChainId,
      remoteConfig["counter"],
      accum
    );
    console.log(`Set config for ${remoteChainId} chain id!`)

  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

async function configNotary(notaryAddr: string, socketSigner: SignerWithAddress) {
  try {
    const localChainId = await getChainId();
    const notary: Contract = await getInstance("AdminNotary", notaryAddr);
    const tx = await notary.connect(socketSigner).grantAttesterRole(remoteChainId, attesterAddress[localChainId]);
    await tx.wait();
    console.log(`Added ${attesterAddress[localChainId]} as an attester for ${remoteChainId} chain id!`)
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

async function configSocket(socket: Contract, socketSigner: SignerWithAddress, remoteChainId: number, localConfig: JSON) {
  try {
    let tx = await socket.connect(socketSigner).addConfig(
      remoteChainId,
      localConfig[`fastAccum-${remoteChainId}`],
      localConfig[`deaccum`],
      localConfig["verifier"],
      fastIntegration
    );

    await tx.wait();

    tx = await socket.connect(socketSigner).addConfig(
      remoteChainId,
      localConfig[`slowAccum-${remoteChainId}`],
      localConfig[`deaccum`],
      localConfig["verifier"],
      slowIntegration
    );

    await tx.wait();

    console.log(`Added slow and fast config for ${remoteChainId} chain id!`)

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
