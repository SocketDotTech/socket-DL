import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, ContractFactory } from "ethers";
import { getChainId } from "../utils";

export default async function deploySocket(hasher: Contract, vault: Contract, signer: SignerWithAddress) {
  try {
    const chainId = await getChainId();

    const Socket: ContractFactory = await ethers.getContractFactory("Socket");
    const socketContract: Contract = await Socket.connect(signer).deploy(chainId, hasher.address, vault.address);
    await socketContract.deployed();

    return socketContract;
  } catch (error) {
    throw error;
  }
}
