import { Contract, Signer } from "ethers";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { attestGasLimit } from "../constants";
import { getSigner } from "./utils/relayer.config";
import * as FastSwitchboardABI from "../../artifacts/contracts/switchboard/default-switchboards/FastSwitchboard.sol/FastSwitchboard.json";
import { isTransactionSuccessful } from "./utils/transaction-helper";

export const setAttestGasLimit = async (
  srcChainSlug: number,
  dstChainSlug: number,
  switchboardAddress: string
) => {
  try {
    const signer: Signer = getSigner(srcChainSlug);

    const signerAddress: string = await signer.getAddress();

    const fastSwitchBoardInstance: Contract = new Contract(
      switchboardAddress,
      FastSwitchboardABI.abi,
      signer
    );

    //TODO set AttestGasLimit in switchboard
    const attestGasLimitValue = attestGasLimit[srcChainSlug];

    // get nextNonce from switchboard
    let nonce: number = await fastSwitchBoardInstance.nextNonce(signerAddress);

    const digest = keccak256(
      defaultAbiCoder.encode(
        ["string", "uint32", "uint32", "uint256", "uint256"],
        [
          "ATTEST_GAS_LIMIT_UPDATE",
          srcChainSlug,
          dstChainSlug,
          nonce,
          attestGasLimitValue,
        ]
      )
    );

    const signature = await signer.signMessage(arrayify(digest));

    const tx = await fastSwitchBoardInstance.setAttestGasLimit(
      nonce,
      dstChainSlug,
      attestGasLimitValue,
      signature
    );

    await tx.wait();

    return isTransactionSuccessful(tx.hash, srcChainSlug);
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};
