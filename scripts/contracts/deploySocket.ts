import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, ContractFactory } from "ethers";
import { getChainId } from "../utils";

export default async function deploySocket(hasher: Contract, signer: SignerWithAddress) {
  try {
    const chainId = await getChainId();

    const Notary: ContractFactory = await ethers.getContractFactory("Socket");
    const notaryContract: Contract = await Notary.connect(signer).deploy(chainId, hasher.address);
    await notaryContract.deployed();

    return notaryContract;
  } catch (error) {
    throw error;
  }
}
