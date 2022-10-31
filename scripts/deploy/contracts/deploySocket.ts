import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, ContractFactory } from "ethers";
import { getChainId, verify } from "../utils";

export default async function deploySocket(hasher: Contract, vault: Contract, signer: SignerWithAddress) {
  try {
    const chainId = await getChainId();
    const contractName = "Socket";
    const args = [chainId, hasher.address, vault.address]

    const Socket: ContractFactory = await ethers.getContractFactory(contractName);
    const socketContract: Contract = await Socket.connect(signer).deploy(...args);
    await socketContract.deployed();

    await verify(socketContract.address, contractName, args);
    return socketContract;
  } catch (error) {
    throw error;
  }
}
