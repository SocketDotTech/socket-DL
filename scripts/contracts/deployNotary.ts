import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, ContractFactory } from "ethers";
import { getChainId, verify } from "../utils";
import { slowPathWaitTime } from "../config";

export default async function deployNotary(signatureVerifier: Contract, signer: SignerWithAddress) {
  try {
    const chainId = await getChainId();
    const contractName = "AdminNotary";
    const args = [signatureVerifier.address, chainId, slowPathWaitTime[chainId]]

    const Notary: ContractFactory = await ethers.getContractFactory(contractName);
    const notaryContract: Contract = await Notary.connect(signer).deploy(...args);
    await notaryContract.deployed();

    await verify(notaryContract.address, contractName, args);
    return notaryContract;
  } catch (error) {
    throw error;
  }
}
