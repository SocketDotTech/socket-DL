import { bridgeConsts, chainSlugs } from "../../constants";

const executionOverhead = 300000;
const initiateGasLimit = 300000;

export const polygonL1Switchboard = (
  network: string,
  socketAddress: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "PolygonL1Switchboard",
    args: [
      chainSlugs[network],
      initiateGasLimit,
      executionOverhead,
      bridgeConsts.checkpointManager[network],
      bridgeConsts.fxRoot[network],
      signerAddress,
      socketAddress,
      oracleAddress,
    ],
    path: "contracts/switchboard/native/PolygonL1Switchboard.sol",
  };
};
