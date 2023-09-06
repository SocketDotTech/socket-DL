require("dotenv").config();
import { utils, BigNumber, providers } from "ethers";
import { ArbGasInfo__factory } from "@arbitrum/sdk/dist/lib/abi/factories/ArbGasInfo__factory";
import { NodeInterface__factory } from "@arbitrum/sdk/dist/lib/abi/factories/NodeInterface__factory";
import {
  ARB_GAS_INFO,
  NODE_INTERFACE_ADDRESS,
} from "@arbitrum/sdk/dist/lib/dataEntities/constants";
import { defaultAbiCoder } from "ethers/lib/utils";
import { DeploymentMode, getAddresses } from "@socket.tech/dl-core";
import PlugABI from "@socket.tech/dl-core/artifacts/abi/IPlug.json";
import { addresses, dstChainSlug, srcChainSlug } from "./config";

const dstChainRPC = process.env.ARBITRUM_RPC;

export const getArbitrumGasEstimate = async (
  amount: string,
  receiver: string
): Promise<BigNumber> => {
  const provider = new providers.StaticJsonRpcProvider(dstChainRPC);

  const arbGasInfo = ArbGasInfo__factory.connect(ARB_GAS_INFO, provider);
  const nodeInterface = NodeInterface__factory.connect(
    NODE_INTERFACE_ADDRESS,
    provider
  );
  // Getting the gas prices from ArbGasInfo.getPricesInWei()
  const gasComponents = await arbGasInfo.callStatic.getPricesInWei();

  const payload = defaultAbiCoder.encode(
    ["address", "uint256"],
    [receiver, amount]
  );
  const abiInterface = new utils.Interface(PlugABI);
  const txData = abiInterface.encodeFunctionData("inbound", [
    srcChainSlug,
    payload,
  ]);

  const gasEstimateComponents =
    await nodeInterface.callStatic.gasEstimateComponents(
      addresses[dstChainSlug].USDC.connectors[srcChainSlug].FAST,
      false,
      txData,
      { from: getAddresses(dstChainSlug, DeploymentMode.PROD).Socket }
    );

  const l2GasUsed = gasEstimateComponents.gasEstimate.sub(
    gasEstimateComponents.gasEstimateForL1
  );
  const L1S = 140 + utils.hexDataLength(txData);
  const L1C = gasComponents[1].mul(L1S);
  const B = L1C.div(gasComponents[5]);

  // G (Gas Limit) = l2GasUsed + B
  const gasLimit = l2GasUsed.add(B);
  return gasLimit;
};
