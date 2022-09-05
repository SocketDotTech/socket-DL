import hre from "hardhat";
import { ethers } from "hardhat";

import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deployContractWithoutArgs, getChainId, storeAddresses } from "../scripts/utils";

import { deployAccumulator, deployCounter, deployNotary, deploySocket, deployVerifier } from "../scripts/contracts";
import { signerAddress } from "../scripts/config";

export const main = async () => {
  try {
    // assign deployers
    const { getNamedAccounts } = hre;
    const { socketOwner, counterOwner } = await getNamedAccounts();

    const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);
    const counterSigner: SignerWithAddress = await ethers.getSigner(counterOwner);

    // Socket deployments
    const hasher: Contract = await deployContractWithoutArgs("Hasher", socketSigner);
    const signatureVerifier: Contract = await deployContractWithoutArgs("SignatureVerifier", socketSigner);
    const notary: Contract = await deployNotary(signatureVerifier, socketSigner);

    const socket: Contract = await deploySocket(hasher, socketSigner, notary);

    const accum: Contract = await deployAccumulator(socket, notary, socketSigner);
    const deaccum: Contract = await deployContractWithoutArgs("SingleDeaccum", socketSigner);

    const verifier: Contract = await deployVerifier(socket, counterSigner)

    // plug deployments
    const counter: Contract = await deployCounter(socket, counterSigner);
    console.log("Contracts deployed!");

    // configure
    const chainId = await getChainId();
    await socket.connect(socketSigner).setNotary(notary.address);

    const addresses = {
      hasher: hasher.address,
      signatureVerifier: signatureVerifier.address,
      socket: socket.address,
      notary: notary.address,
      accum: accum.address,
      deaccum: deaccum.address,
      verifier: verifier.address,
      counter: counter.address
    }

    await storeAddresses(addresses, chainId);
  } catch (error) {
    console.log("Error in deploying setup contracts", error);
    throw error;
  }
};

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
