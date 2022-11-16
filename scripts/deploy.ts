import hre from "hardhat";
import { ethers } from "hardhat";

import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deployContractWithoutArgs, getChainId, storeAddresses } from "./utils";

import {
  deployAccumulator,
  deployCounter,
  deployNotary,
  deploySocket,
  deployVault,
  deployVerifier,
} from "../scripts/contracts";
import { executorAddress, totalRemoteChains } from "./config";
import { ChainAddresses, ChainSocketAddresses } from "../src/types";

export const main = async () => {
  try {
    // assign deployers
    const { getNamedAccounts } = hre;
    const { socketOwner, counterOwner } = await getNamedAccounts();

    const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);
    const counterSigner: SignerWithAddress = await ethers.getSigner(
      counterOwner
    );

    // notary
    const signatureVerifier: Contract = await deployContractWithoutArgs(
      "SignatureVerifier",
      socketSigner
    );
    const notary: Contract = await deployNotary(
      signatureVerifier,
      socketSigner
    );

    // socket
    const hasher: Contract = await deployContractWithoutArgs(
      "Hasher",
      socketSigner
    );
    const vault: Contract = await deployVault(socketSigner);
    const socket: Contract = await deploySocket(hasher, vault, socketSigner);

    // plug deployments
    const verifier: Contract = await deployVerifier(
      notary,
      socket,
      counterSigner
    );
    const counter: Contract = await deployCounter(socket, counterSigner);
    console.log("Contracts deployed!");

    // configure
    const chainId = await getChainId();

    await socket
      .connect(socketSigner)
      .grantExecutorRole(executorAddress[chainId]);
    console.log(`Assigned executor role to ${executorAddress[chainId]}!`);

    // accum & deaccum deployments
    let fastAccumAddresses: ChainAddresses = {};
    let slowAccumAddresses: ChainAddresses = {};
    let deaccumAddresses: ChainAddresses = {};

    for (let index = 0; index < totalRemoteChains.length; index++) {
      const remoteChain = totalRemoteChains[index];

      const fastAccum: Contract = await deployAccumulator(
        socket.address,
        notary.address,
        remoteChain,
        socketSigner
      );
      const slowAccum: Contract = await deployAccumulator(
        socket.address,
        notary.address,
        remoteChain,
        socketSigner
      );
      const deaccum: Contract = await deployContractWithoutArgs(
        "SingleDeaccum",
        socketSigner
      );
      console.log(`Deployed accum and deaccum for ${remoteChain} chain id`);

      fastAccumAddresses[remoteChain] = fastAccum.address;
      slowAccumAddresses[remoteChain] = slowAccum.address;
      deaccumAddresses[remoteChain] = deaccum.address;
    }

    const addresses: ChainSocketAddresses = {
      counter: counter.address,
      hasher: hasher.address,
      notary: notary.address,
      signatureVerifier: signatureVerifier.address,
      socket: socket.address,
      vault: vault.address,
      verifier: verifier.address,
      fastAccum: fastAccumAddresses,
      slowAccum: slowAccumAddresses,
      deaccum: deaccumAddresses,
    };

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
