import hre from "hardhat";
import { ethers } from "hardhat";

import { Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { deployContractWithoutArgs, storeAddresses } from "./utils";
import { chainIds } from "../constants/networks"

import { deployCounter, deploySocket, deployVault } from "./contracts";
import { executorAddress } from "../constants/config";
import { ChainSocketAddresses } from "./types";

/**
 * Deploys network-independent socket contracts
 */
export const main = async () => {
  try {
    // assign deployers
    const { getNamedAccounts } = hre;
    const { socketOwner, counterOwner } = await getNamedAccounts();

    const socketSigner: SignerWithAddress = await ethers.getSigner(socketOwner);
    const counterSigner: SignerWithAddress = await ethers.getSigner(counterOwner);

    const network = hre.network.name;
    const signatureVerifier: Contract = await deployContractWithoutArgs("SignatureVerifier", socketSigner);
    const hasher: Contract = await deployContractWithoutArgs("Hasher", socketSigner);
    const vault: Contract = await deployVault(socketSigner);
    const deaccum: Contract = await deployContractWithoutArgs("SingleDeaccum", socketSigner);
    const socket: Contract = await deploySocket(chainIds[network], hasher, vault, socketSigner);

    // plug deployments
    const counter: Contract = await deployCounter(socket, counterSigner);

    let addresses: ChainSocketAddresses = {
      Counter: counter.address,
      Hasher: hasher.address,
      SignatureVerifier: signatureVerifier.address,
      Socket: socket.address,
      Vault: vault.address,
      SingleDeaccum: deaccum.address
    }
    console.log("Contracts deployed!");

    // configure
    await socket.connect(socketSigner).grantExecutorRole(executorAddress[network]);
    console.log(`Assigned executor role to ${executorAddress[network]} !`)

    await storeAddresses(addresses, chainIds[network]);
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
