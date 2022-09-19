import fs from "fs";
import path from "path";
import { getNamedAccounts, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { signerAddress, srcChainId, destChainId, isFast, executorAddress } from "./config";
import { getInstance, deployContractWithoutArgs } from "./utils";
import { deployAccumulator } from "./contracts";
import { Contract } from "ethers";

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

    const counter = await getInstance("Counter", srcConfig["counter"]);
    const notary = await getInstance("AdminNotary", srcConfig["notary"]);
    const socket = await getInstance("Socket", srcConfig["socket"]);
    const verifier = await getInstance("Verifier", srcConfig["verifier"]);

    const accum: Contract = await deployAccumulator(socket, notary, socketSigner);
    const deaccum: Contract = await deployContractWithoutArgs("SingleDeaccum", socketSigner);

    console.log(accum.address, deaccum.address, `Deployed accum and deaccum for ${srcChainId} & ${destChainId}`);
  
    await notary.connect(socketSigner).grantAttesterRole(destChainId, signerAddress[srcChainId]);
    console.log(`Added ${signerAddress[srcChainId]} as an attester for ${destChainId} chain id!`)

    await notary.addAccumulator(accum.address, destChainId, isFast);
    console.log(`Added accumulator ${accum.address} to Notary!`)

    await counter.connect(counterSigner).setSocketConfig(
      destChainId,
      destConfig["counter"],
      accum.address,
      deaccum.address,
      verifier.address
    );
    console.log(`Set config role for ${destChainId} chain id!`)

    await socket.connect(socketSigner).grantExecutorRole(executorAddress[srcChainId]);
    console.log(`Assigned executor role to ${executorAddress[srcChainId]}!`)

    await verifier.connect(counterSigner).addPauser(pauserSigner.address, destChainId);
    console.log(`Added pauser ${pauserSigner.address} for ${destChainId} chain id!`)

    await verifier.connect(pauserSigner).activate(destChainId);
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
