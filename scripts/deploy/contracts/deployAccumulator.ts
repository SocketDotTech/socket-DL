import { ethers } from "hardhat";
import { ContractFactory, Contract } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { verify } from "../utils";
import { bridgeConsts, chainIds } from "../../constants";

export default async function deployAccumulator(
  contractName: string,
  chain: string,
  socketAddress: string,
  notaryAddress: string,
  remoteChain: string,
  signer: SignerWithAddress
) {
  try {
    let args = {
      ArbitrumL1Accum: [
        socketAddress,
        notaryAddress,
        bridgeConsts.inbox[chain],
        chainIds[remoteChain],
        chainIds[chain],
      ],
      ArbitrumL2Accum: [
        socketAddress,
        notaryAddress,
        chainIds[remoteChain],
        chainIds[chain],
      ],
      SingleAccum: [socketAddress, notaryAddress, chainIds[remoteChain]],
      OptimismAccum: [
        socketAddress,
        notaryAddress,
        chainIds[remoteChain],
        chainIds[chain],
      ],
      PolygonChildAccum: [
        bridgeConsts.fxChild[chain],
        socketAddress,
        notaryAddress,
        chainIds[remoteChain],
        chainIds[chain],
      ],
      PolygonRootAccum: [
        bridgeConsts.checkpointManager[chain],
        bridgeConsts.fxRoot[chain],
        socketAddress,
        notaryAddress,
        chainIds[remoteChain],
        chainIds[chain],
      ],
    };

    const Accumulator: ContractFactory = await ethers.getContractFactory(
      contractName
    );
    const accumContract: Contract = await Accumulator.connect(signer).deploy(
      ...args[contractName]
    );
    await accumContract.deployed();

    await verify(accumContract.address, contractName, args[contractName]);
    return accumContract;
  } catch (error) {
    throw error;
  }
}
