import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, ContractFactory } from "ethers";
import { verify } from "../utils";

export default async function deployNotary(contractName: string, chainId: number, signatureVerifier: string, signer: SignerWithAddress, remoteTarget: string, inboxAddress: string) {
  try {
    let args: any;
    if (contractName === "AdminNotary") {
      args = [signatureVerifier, chainId]
    } else if (contractName === "NativeBridgeNotary") {
      args = [signatureVerifier, chainId, remoteTarget, inboxAddress]
    }

    const Notary: ContractFactory = await ethers.getContractFactory(contractName);
    const notaryContract: Contract = await Notary.connect(signer).deploy(...args);
    await notaryContract.deployed();

    await verify(notaryContract.address, contractName, args);
    return notaryContract;
  } catch (error) {
    throw error;
  }
}
