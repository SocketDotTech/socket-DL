import { utils, BigNumber } from "ethers";
import { ArbGasInfo__factory } from "@arbitrum/sdk/dist/lib/abi/factories/ArbGasInfo__factory";
import { NodeInterface__factory } from "@arbitrum/sdk/dist/lib/abi/factories/NodeInterface__factory";
import {
  ARB_GAS_INFO,
  NODE_INTERFACE_ADDRESS,
} from "@arbitrum/sdk/dist/lib/dataEntities/constants";
import { TxData } from "./utils";
import { StaticJsonRpcProvider } from "@ethersproject/providers";

export const getArbitrumGasLimitEstimate = async (
  provider: StaticJsonRpcProvider,
  txData: TxData
): Promise<BigNumber> => {
  const arbGasInfo = ArbGasInfo__factory.connect(ARB_GAS_INFO, provider);
  const nodeInterface = NodeInterface__factory.connect(
    NODE_INTERFACE_ADDRESS,
    provider
  );
  // Getting the gas prices from ArbGasInfo.getPricesInWei()
  const gasComponents = await arbGasInfo.callStatic.getPricesInWei();
  const gasEstimateComponents =
    await nodeInterface.callStatic.gasEstimateComponents(
      txData.to,
      false,
      txData.data,
      { from: txData.from }
    );

  const l2GasUsed = gasEstimateComponents.gasEstimate.sub(
    gasEstimateComponents.gasEstimateForL1
  );

  // Size in bytes of the calldata to post on L1
  const L1S = 140 + utils.hexDataLength(txData.data);

  // Estimated L1 gas cost
  const L1C = gasComponents[1].mul(L1S);

  // Extra buffer
  const B = L1C.div(gasComponents[5]);

  // G (Gas Limit) = l2GasUsed + B
  const gasLimit = l2GasUsed.add(B);
  return gasLimit;
};
