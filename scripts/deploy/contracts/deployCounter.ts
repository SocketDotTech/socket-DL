import { ethers } from "hardhat";
import { ContractFactory, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { verify } from "../utils";

export default async function deployCounter(socket: Contract, signer: SignerWithAddress) {
  try {
    const contractName = "Counter";
    const args = [socket.address]

    const Counter: ContractFactory = await ethers.getContractFactory(contractName);
    const counterContract: Contract = await Counter.connect(signer).deploy(...args);
    await counterContract.deployed();

    await verify(counterContract.address, contractName, args);

    return counterContract;
  } catch (error) {
    throw error;
  }
};
