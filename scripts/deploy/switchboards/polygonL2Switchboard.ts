import { bridgeConsts } from "../../constants";

const executionOverhead = 300000
const initialConfirmationGasLimit = 300000
const l1ReceiveGasLimit = 300000

export const polygonL2Switchboard = (
  network: string,
  socketAddress: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return { contractName: "PolygonL2Switchboard", args: [l1ReceiveGasLimit, initialConfirmationGasLimit, executionOverhead, bridgeConsts.fxChild[network], signerAddress, socketAddress, oracleAddress] }
};
