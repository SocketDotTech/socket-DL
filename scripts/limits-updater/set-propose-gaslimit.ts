import { Contract, Signer } from "ethers";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import * as SocketBatcherABI from "../../artifacts/contracts/socket/SocketBatcher.sol/SocketBatcher.json";
import * as TransmitManagerABI from "../../artifacts/contracts/TransmitManager.sol/TransmitManager.json";

import { isTransactionSuccessful } from "./utils/transaction-helper";
import { networkToChainSlug, proposeGasLimit } from "../constants";

export const setProposeGasLimit = async (
  srcChainId: number,
  dstChainIds: number[],
  transmitManagerAddress: string,
  socketBatcherAddress: string,
  signer: Signer
) => {
  try {
    const transmitterAddress: string = await signer.getAddress();
    const socketBatcherInstance: Contract = new Contract(
      socketBatcherAddress,
      SocketBatcherABI.abi,
      signer
    );
    const transmitManagerInstance: Contract = new Contract(
      transmitManagerAddress,
      TransmitManagerABI.abi,
      signer
    );

    // get nextNonce from TransmitManager
    let nonce: number = await transmitManagerInstance.nextNonce(
      transmitterAddress
    );

    const setProposeGasLimitsArgs: [number, number, number, string][] = [];
    for (let index = 0; index < dstChainIds.length; index++) {
      const digest = keccak256(
        defaultAbiCoder.encode(
          ["string", "uint256", "uint256", "uint256", "uint256"],
          [
            "PROPOSE_GAS_LIMIT_UPDATE",
            srcChainId,
            dstChainIds[index],
            nonce,
            proposeGasLimit[networkToChainSlug[dstChainIds[index]]],
          ]
        )
      );

      const signature: string = await signer.signMessage(arrayify(digest));
      setProposeGasLimitsArgs.push([
        nonce++,
        dstChainIds[index],
        proposeGasLimit[networkToChainSlug[dstChainIds[index]]],
        signature,
      ]);
    }

    const tx = await socketBatcherInstance.setProposeGasLimits(
      transmitManagerAddress,
      setProposeGasLimitsArgs
    );

    console.log(
      "setting propose gas limits in batch",
      tx.hash,
      srcChainId,
      dstChainIds,
      setProposeGasLimitsArgs
    );
    await tx.wait();

    return isTransactionSuccessful(tx.hash, srcChainId);
  } catch (error) {
    console.log("Error while sending transaction", error);
  }
};
