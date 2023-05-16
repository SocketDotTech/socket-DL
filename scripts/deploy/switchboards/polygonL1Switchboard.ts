import { chainKeyToSlug } from "../../../src";
import { bridgeConsts } from "../../constants";

export const polygonL1Switchboard = (
  network: string,
  socketAddress: string,
  sigVerifierAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "PolygonL1Switchboard",
    args: [
      chainKeyToSlug[network],
      bridgeConsts.checkpointManager[network],
      bridgeConsts.fxRoot[network],
      signerAddress,
      socketAddress,
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/native/PolygonL1Switchboard.sol",
  };
};
