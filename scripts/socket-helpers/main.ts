require("dotenv").config();
import { BigNumber, providers, utils } from "ethers";
import { DeploymentMode } from "@socket.tech/dl-core";
import PlugABI from "@socket.tech/dl-core/artifacts/abi/IPlug.json";

import { ChainDetails, Inputs, getPayload } from "./utils";
import { getJsonRpcUrl } from "../constants";
import { ChainSlug, arbChains, arbL3Chains, getAddresses } from "../../src";
import { getArbitrumGasLimitEstimate } from "./arb-estimate";
import { getOptimismGasLimitEstimate } from "./opt-estimate";

export const getEstimatedGasLimit = async (
  chainDetails: ChainDetails,
  inputs: Inputs,
  withoutHook?: boolean
): Promise<BigNumber> => {
  const srcChainSlug = chainDetails.srcChainSlug as ChainSlug;
  const dstChainSlug = chainDetails.dstChainSlug as ChainSlug;

  const provider = new providers.StaticJsonRpcProvider(
    getJsonRpcUrl(dstChainSlug)
  );
  const payload = getPayload(
    inputs,
    inputs.connectorPlug,
    provider,
    withoutHook
  );

  const abiInterface = new utils.Interface(PlugABI);
  const data = abiInterface.encodeFunctionData("inbound", [
    srcChainSlug,
    payload,
  ]);

  const txData = {
    from: getAddresses(dstChainSlug, DeploymentMode.PROD).Socket,
    to: inputs.connectorPlug,
    data,
  };
  if (
    arbChains.includes(chainDetails.dstChainSlug) ||
    arbL3Chains.includes(chainDetails.dstChainSlug)
  ) {
    return await getArbitrumGasLimitEstimate(provider, txData);
  } else return await getOptimismGasLimitEstimate(provider, txData);
};
