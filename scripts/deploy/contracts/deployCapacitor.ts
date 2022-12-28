import { ethers } from "hardhat";
import { ContractFactory, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { verify } from "../utils";
import { chainIds } from "../../constants";

export default async function deployCapacitor(
  socketAddress: string,
  notaryAddress: string,
  remoteChain: string,
  signer: SignerWithAddress
) {
  try {
    const args = [socketAddress, notaryAddress, chainIds[remoteChain]];
    const Capacitor: ContractFactory = await ethers.getContractFactory(
      "SingleCapacitor"
    );
    const capacitorContract: Contract = await Capacitor.connect(signer).deploy(
      ...args
    );
    await capacitorContract.deployed();

    await verify(capacitorContract.address, "SingleCapacitor", args);
    return capacitorContract;
  } catch (error) {
    throw error;
  }
}
