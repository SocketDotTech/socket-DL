import { chainKeyToSlug } from "../../../src";
import { bridgeConsts } from "../../constants";

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
      chainKeyToSlug[network],
      initiateGasLimit,
      bridgeConsts.checkpointManager[network],
      bridgeConsts.fxRoot[network],
      signerAddress,
      socketAddress,
      oracleAddress,
    ],
    path: "contracts/switchboard/native/PolygonL1Switchboard.sol",
  };
};
