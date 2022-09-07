import { ethers } from "hardhat";
import { ContractFactory, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

export default async function deployAccumulator(socket: Contract, notary: Contract, signer: SignerWithAddress) {
  try {
    const Accumulator: ContractFactory = await ethers.getContractFactory("SingleAccum");
    const accumContract: Contract = await Accumulator.connect(signer).deploy(socket.address, notary.address);
    await accumContract.deployed();

    return accumContract;
  } catch (error) {
    throw error;
  }
};
