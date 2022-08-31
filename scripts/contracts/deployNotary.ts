import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, ContractFactory } from "ethers";
import { getChainId } from "../utils";
import { timeout, waitTime } from "../config";

export default async function deployNotary(signatureVerifier: Contract, signer: SignerWithAddress) {
  try {
    const chainId = await getChainId();

    const Notary: ContractFactory = await ethers.getContractFactory("AdminNotary");
    const notaryContract: Contract = await Notary.connect(signer).deploy(signatureVerifier.address, chainId, timeout[chainId], waitTime[chainId]);
    await notaryContract.deployed();

    return notaryContract;
  } catch (error) {
    throw error;
  }
}
