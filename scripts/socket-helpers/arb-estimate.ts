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

const addresses = {
  "10": {
    USDC: {
      connectors: {
        "2999": {
          FAST: "0x1812ff6bd726934f18159164e2927B34949B16a8",
        },
      },
    },
  },
  "2999": {
    USDC: {
      connectors: {
        "10": {
          FAST: "0x7b9ed5C43E87DAFB03211651d4FA41fEa1Eb9b3D",
        },
        "42161": {
          FAST: "0x73019b64e31e699fFd27d54E91D686313C14191C",
        },
      },
    },
  },
  "42161": {
    USDC: {
      connectors: {
        "2999": {
          FAST: "0x69Adf49285c25d9f840c577A0e3cb134caF944D3",
        },
      },
    },
  },
};

const srcChainSlug = 2999;
const dstChainSlug = 42161;
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
