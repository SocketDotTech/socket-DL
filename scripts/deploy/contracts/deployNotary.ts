import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Contract, ContractFactory } from "ethers";
import { verify } from "../utils";
import { bridgeConsts, chainIds } from "../../constants";

export default async function deployNotary(
  contractName: string,
  chain: string,
  signatureVerifier: string,
  remoteTarget: string,
  signer: SignerWithAddress
) {
  try {
    let args = {
      AdminNotary: [signatureVerifier, chainIds[chain]],
      ArbitrumNotary: [
        signatureVerifier,
        chainIds[chain],
        remoteTarget,
        bridgeConsts.inbox[chain],
      ],
      OptimismNotary: [signatureVerifier, chainIds[chain], remoteTarget],
      PolygonL2Notary: [
        signatureVerifier,
        chainIds[chain],
        remoteTarget,
        bridgeConsts.fxChild[chain],
      ],
      PolygonL1Notary: [
        bridgeConsts.checkpointManager[chain],
        bridgeConsts.fxRoot[chain],
        signatureVerifier,
        chainIds[chain],
        remoteTarget,
      ],
    };

    const Notary: ContractFactory = await ethers.getContractFactory(
      contractName
    );
    const notaryContract: Contract = await Notary.connect(signer).deploy(
      ...args[contractName]
    );
    await notaryContract.deployed();

    await verify(notaryContract.address, contractName, args[contractName]);
    return notaryContract;
  } catch (error) {
    throw error;
  }
}
