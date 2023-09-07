require("dotenv").config();
import { BigNumber, providers, utils } from "ethers";
import { asL2Provider } from "@eth-optimism/sdk";
import { defaultAbiCoder } from "ethers/lib/utils";
import PlugABI from "@socket.tech/dl-core/artifacts/abi/IPlug.json";
import { addresses, dstChainSlug, srcChainSlug } from "./config";
import { DeploymentMode, getAddresses } from "@socket.tech/dl-core";

const dstChainRPC = process.env.OPTIMISM_RPC;

// Get optimism gas limit from the SDK
export const getOptimismGasEstimate = async (
  amount: string,
  receiver: string
): Promise<BigNumber> => {
  const provider = new providers.StaticJsonRpcProvider(dstChainRPC);
  const l2Provider = asL2Provider(provider);

  const payload = defaultAbiCoder.encode(
    ["address", "uint256"],
    [receiver, amount]
  );
  const abiInterface = new utils.Interface(PlugABI);
  const data = abiInterface.encodeFunctionData("inbound", [
    srcChainSlug,
    payload,
  ]);

  const gasLimit = await l2Provider.estimateGas({
    data,
    to: addresses[dstChainSlug].USDC.connectors[srcChainSlug].FAST,
    from: getAddresses(dstChainSlug, DeploymentMode.PROD).Socket,
  });
  return gasLimit;
};
