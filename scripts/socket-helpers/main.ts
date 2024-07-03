require("dotenv").config();
import { BigNumber, providers, utils } from "ethers";
import { DeploymentMode } from "@socket.tech/dl-core";
import PlugABI from "@socket.tech/dl-core/artifacts/abi/IPlug.json";

import { ChainDetails, Inputs, getPayload } from "./utils";
import { getJsonRpcUrl } from "../constants";
import { arbChains, arbL3Chains, getAddresses } from "../../src";
import { getArbitrumGasLimitEstimate } from "./arb-estimate";
import { getOpAndEthGasLimitEstimate } from "./op-n-eth-estimate";

export const main = async (
  chainDetails: ChainDetails,
  inputs: Inputs,
  withoutHook?: boolean
): Promise<BigNumber> => {
  const srcChainSlug = chainDetails.srcChainSlug;
  const dstChainSlug = chainDetails.dstChainSlug;

  const provider = new providers.StaticJsonRpcProvider(
    getJsonRpcUrl(dstChainSlug)
  );
  const payload = await getPayload(inputs, provider, withoutHook);

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
  } else {
    // works for opt and eth like chains
    return await getOpAndEthGasLimitEstimate(provider, txData);
  }
};

main(
  {
    srcChainSlug: 42161,
    dstChainSlug: 1324967486,
  },
  {
    amount: "2000000000",
    connectorPlug: "0x663dc7e91157c58079f55c1bf5ee1bdb6401ca7a",
    executionData: "0x",
    receiver: "0x663dc7e91157c58079f55c1bf5ee1bdb6401ca7a",
  },
  false
);
