import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, ContractFactory } from "ethers";

export default async function deployVault(signer: SignerWithAddress) {
  try {
    const vault: ContractFactory = await ethers.getContractFactory("Vault");
    const vaultContract: Contract = await vault.connect(signer).deploy(signer.address);
    await vaultContract.deployed();

    return vaultContract;
  } catch (error) {
    throw error;
  }
}