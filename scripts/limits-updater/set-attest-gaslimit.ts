import { Contract, Signer } from "ethers";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import * as FastSwitchboardABI from "../../artifacts/contracts/switchboard/default-switchboards/FastSwitchboard.sol/FastSwitchboard.json";
import * as SocketBatcherABI from "../../artifacts/contracts/socket/SocketBatcher.sol/SocketBatcher.json";

import { isTransactionSuccessful } from "./utils/transaction-helper";
import { attestGasLimit } from "../constants";
import { networkToChainSlug } from "../../src";

export const setAttestGasLimit = async (
  srcChainId: number,
  dstChainIds: number[],
  switchboardAddress: string,
  socketBatcherAddress: string,
  signer: Signer
) => {
  try {
    const signerAddress: string = await signer.getAddress();
    const fastSwitchBoardInstance: Contract = new Contract(
      switchboardAddress,
      FastSwitchboardABI.abi,
      signer
    );

    const socketBatcherInstance: Contract = new Contract(
      socketBatcherAddress,
      SocketBatcherABI.abi,
      signer
    );

    // get nextNonce from switchboard
    let nonce: number = await fastSwitchBoardInstance.nextNonce(signerAddress);
    const setAttestGasLimitsArgs: [number, number, number, string][] = [];

    for (let index = 0; index < dstChainIds.length; index++) {
      const digest = keccak256(
        defaultAbiCoder.encode(
          ["string", "uint256", "uint256", "uint256", "uint256"],
          [
            "ATTEST_GAS_LIMIT_UPDATE",
            srcChainId,
            dstChainIds[index],
            nonce,
            attestGasLimit[networkToChainSlug[dstChainIds[index]]],
          ]
        )
      );

      const signature = await signer.signMessage(arrayify(digest));
      setAttestGasLimitsArgs.push([
        nonce++,
        dstChainIds[index],
        attestGasLimit[networkToChainSlug[dstChainIds[index]]],
        signature,
      ]);
    }

    const tx = await socketBatcherInstance.setAttestGasLimits(
      switchboardAddress,
      setAttestGasLimitsArgs
    );

    console.log(
      "setting attest gas limit",
      tx.hash,
      srcChainId,
      dstChainIds,
      setAttestGasLimitsArgs
    );

    await tx.wait();
    return isTransactionSuccessful(tx.hash, srcChainId);
  } catch (error) {
    console.log("Error while sending transaction", error);
  }
};
