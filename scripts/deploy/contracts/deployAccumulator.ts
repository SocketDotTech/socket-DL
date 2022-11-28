import { ethers } from "hardhat";
import { ContractFactory, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { verify } from "../utils";
import { chainIds } from "../../constants";

export default async function deployAccumulator(
  socketAddress: string,
  notaryAddress: string,
  remoteChain: string,
  signer: SignerWithAddress
) {
  try {
    const args = [socketAddress, notaryAddress, chainIds[remoteChain]]
    const Accumulator: ContractFactory = await ethers.getContractFactory("SingleAccum");
    const accumContract: Contract = await Accumulator.connect(signer).deploy(...args);
    await accumContract.deployed();

    await verify(accumContract.address, "SingleAccum", args);
    return accumContract;
  } catch (error) {
    throw error;
  }
}
