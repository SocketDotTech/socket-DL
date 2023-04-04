import { Contract, Signer } from "ethers";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { executionOverhead } from "../constants";
import { getSigner } from "./utils/relayer.config";
import * as FastSwitchboardABI from "../../artifacts/contracts/switchboard/default-switchboards/FastSwitchboard.sol/FastSwitchboard.json";
import { isTransactionSuccessful } from "./utils/transaction-helper";

export const setExecutionOverhead = async (
  srcChainSlug: number,
  dstChainSlug: number,
  switchboardAddress: string
) => {
  try {
    const signer: Signer = getSigner(srcChainSlug);

    const signerAddress: string = await signer.getAddress();

    const switchBoardInstance: Contract = new Contract(
      switchboardAddress,
      FastSwitchboardABI.abi,
      signer
    );

    //set executionOverhead in switchboard
    const executionOverheadValue = executionOverhead[srcChainSlug];

    // get nextNonce from switchboard
    let nonce: number = await switchBoardInstance.nextNonce(signerAddress);

    const digest = keccak256(
      defaultAbiCoder.encode(
        ["string", "uint256", "uint32", "uint32", "uint256"],
        [
          "ATTEST_GAS_LIMIT_UPDATE",
          nonce,
          srcChainSlug,
          dstChainSlug,
          ,
          executionOverheadValue,
        ]
      )
    );

    const signature = await signer.signMessage(arrayify(digest));

    const tx = await switchBoardInstance.setExecutionOverhead(
      nonce,
      dstChainSlug,
      executionOverheadValue,
      signature
    );

    await tx.wait();

    return isTransactionSuccessful(tx.hash, srcChainSlug);
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};
