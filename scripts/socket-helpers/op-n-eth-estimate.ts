import { BigNumber } from "ethers";
import { StaticJsonRpcProvider } from "@ethersproject/providers";
import { asL2Provider } from "@eth-optimism/sdk";
import { TxData } from "./utils";

// Get optimism gas limit from the SDK
export const getOpAndEthGasLimitEstimate = async (
  provider: StaticJsonRpcProvider,
  txData: TxData
): Promise<BigNumber> => {
  const l2Provider = asL2Provider(provider);
  const gasLimit = await l2Provider.estimateGas(txData);
  return gasLimit;
};
