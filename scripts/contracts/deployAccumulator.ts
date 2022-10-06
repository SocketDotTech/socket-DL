import { ethers } from "hardhat";
import { ContractFactory, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { verify } from "../utils";

export default async function deployAccumulator(socketAddress: string, notaryAddress: string, destChainId_: number, signer: SignerWithAddress) {
  try {
    const contractName = "SingleAccum";
    const args = [socketAddress, notaryAddress, destChainId_]

    const Accumulator: ContractFactory = await ethers.getContractFactory(contractName);
    const accumContract: Contract = await Accumulator.connect(signer).deploy(...args);
    await accumContract.deployed();

    await verify(accumContract.address, contractName, args);
    return accumContract;
  } catch (error) {
    throw error;
  }
};
