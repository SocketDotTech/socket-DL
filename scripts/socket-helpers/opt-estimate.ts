import { BigNumber } from "ethers";
import { asL2Provider } from "@eth-optimism/sdk";
import { TxData } from "./utils";

// Get optimism gas limit from the SDK
export const getOptimismGasLimitEstimate = async (
  provider,
  txData: TxData
): Promise<BigNumber> => {
  const l2Provider = asL2Provider(provider);
  const gasLimit = await l2Provider.estimateGas(txData);
  return gasLimit;
};
