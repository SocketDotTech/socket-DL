import { chainKeyToSlug } from "../../../src";
import { bridgeConsts } from "../../constants";

export const polygonL2Switchboard = (
  network: string,
  socketAddress: string,
  sigVerifierAddress: string,
  signerAddress: string
) => {
  return {
    contractName: "PolygonL2Switchboard",
    args: [
      chainKeyToSlug[network],
      bridgeConsts.fxChild[network],
      signerAddress,
      socketAddress,
      sigVerifierAddress,
    ],
    path: "contracts/switchboard/native/PolygonL2Switchboard.sol",
  };
};
