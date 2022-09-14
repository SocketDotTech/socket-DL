import hre from "hardhat";
import { ethers } from "hardhat";

import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deployContractWithoutArgs, getChainId, storeAddresses } from "./utils";

import { deployAccumulator, deployCounter, deployNotary, deploySocket, deployVault, deployVerifier } from "../scripts/contracts";

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

    const vault: Contract = await deployVault(socketSigner);
    const socket: Contract = await deploySocket(hasher, vault, socketSigner);

    const accum: Contract = await deployAccumulator(socket, notary, socketSigner);
    const deaccum: Contract = await deployContractWithoutArgs("SingleDeaccum", socketSigner);

    const verifier: Contract = await deployVerifier(notary, counterSigner)

    // plug deployments
    const counter: Contract = await deployCounter(socket, counterSigner);
    console.log("Contracts deployed!");

    // configure
    const chainId = await getChainId();

    const addresses = {
      accum: accum.address,
      counter: counter.address,
      deaccum: deaccum.address,
      hasher: hasher.address,
      notary: notary.address,
      signatureVerifier: signatureVerifier.address,
      socket: socket.address,
      vault: vault.address,
      verifier: verifier.address
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
