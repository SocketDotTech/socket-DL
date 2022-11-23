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
      ArbitrumReceiver: [
        signatureVerifier,
        chainIds[chain],
        remoteTarget,
        bridgeConsts.inbox[chain],
      ],
      OptimismReceiver: [signatureVerifier, chainIds[chain], remoteTarget],
      PolygonChildReceiver: [
        signatureVerifier,
        chainIds[chain],
        remoteTarget,
        bridgeConsts.fxChild[chain],
      ],
      PolygonRootReceiver: [
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
