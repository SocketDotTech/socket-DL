import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, ContractFactory } from "ethers";
import { getChainId } from "../utils";
import { timeout } from "../config";

export default async function deployVerifier(socket: Contract, signer: SignerWithAddress) {
  try {
    const chainId = await getChainId();

    const Notary: ContractFactory = await ethers.getContractFactory("AcceptWithTimeout");
    const notaryContract: Contract = await Notary.connect(signer).deploy(timeout[chainId], socket.address, signer.address);
    await notaryContract.deployed();

    return notaryContract;
  } catch (error) {
    throw error;
  }
}