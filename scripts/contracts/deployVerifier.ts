import { ethers, getChainId } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, ContractFactory } from "ethers";
import { timeout } from "../config";
import { verify } from "../utils";

export default async function deployVerifier(notary: Contract, socket: Contract, signer: SignerWithAddress) {
  try {
    const chainId: any = await getChainId();
    const contractName = "Verifier";
    const args = [signer.address, notary.address, socket.address, timeout[chainId]]

    const verifier: ContractFactory = await ethers.getContractFactory(contractName);
    const verifierContract: Contract = await verifier.connect(signer).deploy(...args);
    await verifierContract.deployed();

    await verify(verifierContract.address, contractName, args);

    return verifierContract;
  } catch (error) {
    throw error;
  }
}