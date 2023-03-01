import { bridgeConsts } from "../../constants";

const executionOverhead = 300000;
const initialConfirmationGasLimit = 300000;

export const polygonL1Switchboard = (
  network: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "PolygonL1Switchboard",
    args: [
      initialConfirmationGasLimit,
      executionOverhead,
      bridgeConsts.checkpointManager[network],
      bridgeConsts.fxRoot[network],
      signerAddress,
      oracleAddress,
    ],
    path: "contracts/switchboard/native/PolygonL1Switchboard.sol",
  };
};
