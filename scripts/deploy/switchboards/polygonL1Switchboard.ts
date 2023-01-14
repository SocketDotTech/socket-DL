import { bridgeConsts } from "../../constants";

const executionOverhead = 300000
const initialConfirmationGasLimit = 300000

export const polygonL1Switchboard = (
  network: string,
  socketAddress: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return { contractName: "PolygonL1Switchboard", args: [initialConfirmationGasLimit, executionOverhead, bridgeConsts.checkpointManager[network], bridgeConsts.fxRoot[network], signerAddress, socketAddress, oracleAddress], path: "contracts/switchboard/native/PolygonL1Switchboard.sol" };
};
