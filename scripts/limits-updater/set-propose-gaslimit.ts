import { Contract, Signer } from "ethers";
import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";
import { proposeGasLimit } from "../constants";
import { getSigner } from "./utils/relayer.config";
import * as TransmitManagerABI from "../../artifacts/contracts/TransmitManager.sol/TransmitManager.json";
import { isTransactionSuccessful } from "./utils/transaction-helper";

export const setProposeGasLimit = async (
  srcChainSlug: number,
  dstChainSlug: number,
  transmitManagerAddress: string
) => {
  try {
    const signer: Signer = getSigner(srcChainSlug);

    const transmitterAddress: string = await signer.getAddress();

    const transmitManagerInstance: Contract = new Contract(
      transmitManagerAddress,
      TransmitManagerABI.abi,
      signer
    );

    //fetch proposeGasLimit from config
    const proposeGasLimitValue = proposeGasLimit[srcChainSlug];

    // get nextNonce from TransmitManager
    let nonce: number = await transmitManagerInstance.nextNonce(
      transmitterAddress
    );

    const digest = keccak256(
      defaultAbiCoder.encode(
        ["string", "uint32", "uint32", "uint256", "uint256"],
        [
          "ATTEST_GAS_LIMIT_UPDATE",
          srcChainSlug,
          dstChainSlug,
          nonce,
          proposeGasLimitValue,
        ]
      )
    );

    const signature = await signer.signMessage(arrayify(digest));

    const tx = await transmitManagerInstance.setProposeGasLimit(
      nonce,
      dstChainSlug,
      proposeGasLimitValue,
      signature
    );

    await tx.wait();

    return isTransactionSuccessful(tx.hash, srcChainSlug);
  } catch (error) {
    console.log("Error while sending transaction", error);
    throw error;
  }
};
