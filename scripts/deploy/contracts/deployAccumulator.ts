import { ethers } from "hardhat";
import { ContractFactory, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { verify } from "../utils";

export default async function deployAccumulator(contractName: string, chainSlug: number, socketAddress: string, notaryAddress: string, remoteChainSlug: number, inboxAddress: string, signer: SignerWithAddress) {
  try {
    let args: any;
    if (contractName === "ArbitrumL1Accum") {
      args = [socketAddress, notaryAddress, inboxAddress, remoteChainSlug, chainSlug]
    } else if (contractName === "ArbitrumL2Accum") {
      args = [socketAddress, notaryAddress, remoteChainSlug, chainSlug]
    } else {
      if (contractName.includes("SingleAccum")) contractName = "SingleAccum";
      args = [socketAddress, notaryAddress, remoteChainSlug]
    }

    const Accumulator: ContractFactory = await ethers.getContractFactory(contractName);
    const accumContract: Contract = await Accumulator.connect(signer).deploy(...args);
    await accumContract.deployed();

    await verify(accumContract.address, contractName, args);
    return accumContract;
  } catch (error) {
    throw error;
  }
};
