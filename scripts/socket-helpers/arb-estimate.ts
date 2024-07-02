import { utils, BigNumber } from "ethers";
import { ArbGasInfo__factory } from "@arbitrum/sdk/dist/lib/abi/factories/ArbGasInfo__factory";
import { NodeInterface__factory } from "@arbitrum/sdk/dist/lib/abi/factories/NodeInterface__factory";
import {
  ARB_GAS_INFO,
  NODE_INTERFACE_ADDRESS,
} from "@arbitrum/sdk/dist/lib/dataEntities/constants";
import { TxData } from "./utils";

export const getArbitrumGasLimitEstimate = async (
  provider,
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
  const L1S = 140 + utils.hexDataLength(txData.data);
  const L1C = gasComponents[1].mul(L1S);
  const B = L1C.div(gasComponents[5]);

  // G (Gas Limit) = l2GasUsed + B
  const gasLimit = l2GasUsed.add(B);
  return gasLimit;
};
