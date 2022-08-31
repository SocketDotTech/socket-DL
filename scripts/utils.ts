import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { ContractFactory, Contract } from "ethers";
import { network, ethers } from "hardhat";
import path from "path";
import fs from "fs";
import { Address } from "hardhat-deploy/dist/types";

export const deployContractWithoutArgs = async (contractName: string, signer: SignerWithAddress): Promise<Contract> => {
  try {
    const Contract: ContractFactory = await ethers.getContractFactory(contractName);
    const contractInstance: Contract = await Contract.connect(signer).deploy();
    await contractInstance.deployed();

    return contractInstance;
  } catch (error) {
    throw error;
  }
}

export const getInstance = async (contractName: string, address: Address) => (await ethers.getContractFactory(contractName)).attach(address)

export const getChainId = async (): Promise<number> => {
  if (network.config.chainId === undefined) throw new Error("chain id not found");
  return Number(network.config.chainId)
}

export const storeAddresses = async (addresses: Object, chainId: number) => {
  const dirPath = path.join(__dirname, "../deployments");
  if (!fs.existsSync(dirPath)) {
    await fs.promises.mkdir(dirPath);
  }

  fs.writeFileSync(
    __dirname + `/../deployments/${chainId}.json`,
    JSON.stringify(addresses)
  );
}
