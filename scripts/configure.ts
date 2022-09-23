import fs from "fs";
import path from "path";
import { getNamedAccounts, ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

import { signerAddress, srcChainId, destChainId } from "./config";
import { getInstance, deployContractWithoutArgs, storeAddresses } from "./utils";
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

    let srcConfig: JSON = JSON.parse(fs.readFileSync(deployedAddressPath + srcChainId + ".json", "utf-8"));
    const destConfig: JSON = JSON.parse(fs.readFileSync(deployedAddressPath + destChainId + ".json", "utf-8"))

    const { socketSigner, counterSigner } = await getSigners();

    // fast and slow accum
    const fastAccum: Contract = await deployAccumulator(srcConfig["socket"], srcConfig["notary"], socketSigner);
    const slowAccum: Contract = await deployAccumulator(srcConfig["socket"], srcConfig["notary"], socketSigner);
    const deaccum: Contract = await deployContractWithoutArgs("SingleDeaccum", socketSigner);
    console.log(fastAccum.address, slowAccum.address, deaccum.address, `Deployed accum and deaccum for ${srcChainId} & ${destChainId}`);

    srcConfig[`fastAccum-${destChainId}`] = fastAccum.address;
    srcConfig[`slowAccum-${destChainId}`] = slowAccum.address;
    srcConfig[`deaccum-${destChainId}`] = deaccum.address;
    await storeAddresses(srcConfig, srcChainId)

    const counter: Contract = await getInstance("Counter", srcConfig["counter"]);
    await counter.connect(counterSigner).setSocketConfig(
      destChainId,
      destConfig["counter"],
      fastAccum.address,
      deaccum.address,
      srcConfig["verifier"]
    );
    console.log(`Set config role for ${destChainId} chain id!`)

    await configNotary(srcConfig["notary"], fastAccum.address, slowAccum.address, socketSigner)
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};

async function configNotary(notaryAddr: string, fastAccumAddr: string, slowAccumAddr: string, socketSigner: SignerWithAddress) {
  try {
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
