import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, ContractFactory } from "ethers";
import { verify } from "../utils";

export default async function deployVault(signer: SignerWithAddress) {
  try {
    const contractName = "Vault";
    const args = [signer.address];

    const vault: ContractFactory = await ethers.getContractFactory(
      contractName
    );
    const vaultContract: Contract = await vault.connect(signer).deploy(...args);
    await vaultContract.deployed();

    await verify(vaultContract.address, contractName, args);

    return vaultContract;
  } catch (error) {
    throw error;
  }
}
