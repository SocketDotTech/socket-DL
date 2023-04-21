import { Contract, Signer } from "ethers";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import * as FastSwitchboardABI from "../../artifacts/contracts/switchboard/default-switchboards/FastSwitchboard.sol/FastSwitchboard.json";
import { isTransactionSuccessful } from "./utils/transaction-helper";

export const setExecutionOverhead = async (
  srcChainId: number,
  dstChainId: number,
  switchboardAddress: string,
  executionOverhead: number,
  signer: Signer
) => {
  try {
    const signerAddress: string = await signer.getAddress();
    const switchBoardInstance: Contract = new Contract(
      switchboardAddress,
      FastSwitchboardABI.abi,
      signer
    );

    // get nextNonce from switchboard
    let nonce: number = await switchBoardInstance.nextNonce(signerAddress);

    const digest = keccak256(
      defaultAbiCoder.encode(
        ["string", "uint256", "uint256", "uint256", "uint256"],
        [
          "EXECUTION_OVERHEAD_UPDATE",
          nonce,
          srcChainId,
          dstChainId,
          executionOverhead,
        ]
      )
    );

    const signature = await signer.signMessage(arrayify(digest));

    const tx = await switchBoardInstance.setExecutionOverhead(
      nonce,
      dstChainId,
      executionOverhead,
      signature
    );
    console.log("setting execution overhead", tx.hash, srcChainId);
    await tx.wait();
    return isTransactionSuccessful(tx.hash, srcChainId);
  } catch (error) {
    console.log("Error while sending transaction", error);
  }
};
