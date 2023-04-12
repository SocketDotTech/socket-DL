import { bridgeConsts, chainSlugs } from "../../constants";

const executionOverhead = 300000;
const initiateGasLimit = 300000;
const confirmGasLimit = 300000;

export const polygonL2Switchboard = (
  network: string,
  socketAddress: string,
  oracleAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "PolygonL2Switchboard",
    args: [
      chainSlugs[network],
      confirmGasLimit,
      initiateGasLimit,
      executionOverhead,
      bridgeConsts.fxChild[network],
      signerAddress,
      socketAddress,
      oracleAddress,
    ],
    path: "contracts/switchboard/native/PolygonL2Switchboard.sol",
  };
};
