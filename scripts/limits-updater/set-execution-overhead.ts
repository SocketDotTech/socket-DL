import { Contract, Signer } from "ethers";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import * as FastSwitchboardABI from "../../artifacts/contracts/switchboard/default-switchboards/FastSwitchboard.sol/FastSwitchboard.json";
import * as SocketBatcherABI from "../../artifacts/contracts/socket/SocketBatcher.sol/SocketBatcher.json";

import { isTransactionSuccessful } from "./utils/transaction-helper";
import { executionOverhead } from "../constants";
import { networkToChainSlug } from "../../src";

export const setExecutionOverhead = async (
  srcChainId: number,
  dstChainIds: number[],
  switchboardAddress: string,
  socketBatcherAddress: string,
  signer: Signer
) => {
  try {
    const signerAddress: string = await signer.getAddress();
    const switchBoardInstance: Contract = new Contract(
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
    let nonce: number = await switchBoardInstance.nextNonce(signerAddress);

    const setExecutionOverheadArgs: [number, number, number, string][] = [];
    for (let index = 0; index < dstChainIds.length; index++) {
      const digest = keccak256(
        defaultAbiCoder.encode(
          ["string", "uint256", "uint256", "uint256", "uint256"],
          [
            "EXECUTION_OVERHEAD_UPDATE",
            nonce,
            srcChainId,
            dstChainIds[index],
            executionOverhead[networkToChainSlug[dstChainIds[index]]],
          ]
        )
      );

      const signature = await signer.signMessage(arrayify(digest));
      setExecutionOverheadArgs.push([
        nonce++,
        dstChainIds[index],
        executionOverhead[networkToChainSlug[dstChainIds[index]]],
        signature,
      ]);
    }

    const tx = await socketBatcherInstance.setExecutionOverheadBatch(
      switchboardAddress,
      setExecutionOverheadArgs
    );

    console.log(
      "setting execution overhead",
      tx.hash,
      srcChainId,
      dstChainIds,
      setExecutionOverheadArgs
    );
    await tx.wait();
    return isTransactionSuccessful(tx.hash, srcChainId);
  } catch (error) {
    console.log("Error while sending transaction", error);
  }
};
