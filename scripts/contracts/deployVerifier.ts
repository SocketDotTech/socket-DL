import { ethers, getChainId } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, ContractFactory } from "ethers";
import { timeout } from "../config";

export default async function deployVerifier(socket: Contract, notary: Contract, signer: SignerWithAddress) {
  try {
    const chainId: any = await getChainId();

    const verifier: ContractFactory = await ethers.getContractFactory("Verifier");
    const verifierContract: Contract = await verifier.connect(signer).deploy(socket.address, signer.address, notary.address, timeout[chainId]);
    await verifierContract.deployed();

    return verifierContract;
  } catch (error) {
    throw error;
  }
}