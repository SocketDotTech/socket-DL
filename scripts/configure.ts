import fs from "fs";
import { getNamedAccounts, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { signerAddress, destChainId, isFast } from "./config";
import { getInstance, deployContractWithoutArgs, storeAddresses, deployedAddressPath, getChainId } from "./utils";
import { deployAccumulator } from "./contracts";
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
    const accum = isFast ? srcConfig[`fastAccum-${destChainId}`] : srcConfig[`slowAccum-${destChainId}`];

    await counter.connect(counterSigner).setSocketConfig(
      destChainId,
      destConfig["counter"],
      accum,
      srcConfig[`deaccum-${destChainId}`],
      srcConfig["verifier"]
    );
    console.log(`Set config role for ${destChainId} chain id!`)

    await configNotary(srcConfig["notary"], srcConfig[`fastAccum-${destChainId}`], srcConfig[`slowAccum-${destChainId}`], socketSigner)
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

async function configNotary(notaryAddr: string, fastAccumAddr: string, slowAccumAddr: string, socketSigner: SignerWithAddress) {
  try {
    const srcChainId = await getChainId();
    const notary: Contract = await getInstance("AdminNotary", notaryAddr);

    await notary.connect(socketSigner).grantAttesterRole(destChainId, signerAddress[srcChainId]);
    console.log(`Added ${signerAddress[srcChainId]} as an attester for ${destChainId} chain id!`)

    await notary.connect(socketSigner).addAccumulator(fastAccumAddr, destChainId, true);
    console.log(`Added fast accumulator ${fastAccumAddr} to Notary!`)

    await notary.connect(socketSigner).addAccumulator(slowAccumAddr, destChainId, false);
    console.log(`Added slow accumulator ${slowAccumAddr} to Notary!`)
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

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
