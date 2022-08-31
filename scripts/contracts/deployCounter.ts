import { ethers } from "hardhat";
import { ContractFactory, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";


export default async function deployCounter(socket: Contract, signer: SignerWithAddress) {
  try {
    const Counter: ContractFactory = await ethers.getContractFactory("Counter");
    const counterContract: Contract = await Counter.connect(signer).deploy(socket.address);
    await counterContract.deployed();

    return counterContract;
  } catch (error) {
    throw error;
  }
};
