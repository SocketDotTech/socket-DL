import { Contract, Signer } from "ethers";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import * as FastSwitchboardABI from "../../artifacts/contracts/switchboard/default-switchboards/FastSwitchboard.sol/FastSwitchboard.json";
import { isTransactionSuccessful } from "./utils/transaction-helper";

export const setAttestGasLimit = async (
  srcChainId: number,
  dstChainId: number,
  switchboardAddress: string,
  attestGasLimit: number,
  signer: Signer
) => {
  try {
    const signerAddress: string = await signer.getAddress();
    const fastSwitchBoardInstance: Contract = new Contract(
      switchboardAddress,
      FastSwitchboardABI.abi,
      signer
    );

    // get nextNonce from switchboard
    let nonce: number = await fastSwitchBoardInstance.nextNonce(signerAddress);
    const digest = keccak256(
      defaultAbiCoder.encode(
        ["string", "uint256", "uint256", "uint256", "uint256"],
        [
          "ATTEST_GAS_LIMIT_UPDATE",
          srcChainId,
          dstChainId,
          nonce,
          attestGasLimit,
        ]
      )
    );

    const signature = await signer.signMessage(arrayify(digest));
    const tx = await fastSwitchBoardInstance.setAttestGasLimit(
      nonce,
      dstChainId,
      attestGasLimit,
      signature
    );

    console.log("setting attest gas limit", tx.hash, srcChainId, dstChainId);

    await tx.wait();
    return isTransactionSuccessful(tx.hash, srcChainId);
  } catch (error) {
    console.log("Error while sending transaction", error);
  }
};
